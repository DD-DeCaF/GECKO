%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% kcats = matchKcats(BRENDA_file,model_data)
% Matchs the model EC numbers and substrates to the BRENDA database, to
% return the corresponding kcats for each reaction.
%
% INPUT:    Model data structure (generated by getECnumbers.m)
% OUTPUTS:  kcats, which contains:
%           *forw.kcats:   kcat values for the forward reactions (mxn)
%           *forw.org_s:   Number of matches for organism - substrate in
%                          forward reaction (mxn)
%           *forw.rest_s:  Number of matches for any organism - substrate
%                          in forward reaction (mxn)
%           *forw.org_ns:  Number of matches for organism - any substrate
%                          in forward reaction (mxn)
%           *forw.rest_ns: Number of matches for any organism - any
%                          substrate in forward reaction (mxn)
%           *forw.org_sa:  Number of matches for organism - using s.a.
%                          in forward reaction (mxn)
%           *forw.rest_sa: Number of matches for any organism - using s.a.
%                          in forward reaction (mxn)
%           *back.kcats:   kcat values for the backward reactions (mxn)
%           *back.org_s:   Number of matches for organism - substrate in
%                          backwards reaction (mxn)
%           *back.rest_s:  Number of matches for any organism - substrate
%                          in backwards reaction (mxn)
%           *back.org_ns:  Number of matches for organism - any substrate
%                          in backwards reaction (mxn)
%           *back.rest_ns: Number of matches for any organism - any
%                          substrate in backwards reaction (mxn)
%           *back.org_sa:  Number of matches for organism - using s.a.
%                          in backwards reaction (mxn)
%           *back.rest_sa: Number of matches for any organism - using s.a.
%                          in backwards reaction (mxn)
%           *tot.queries:  The total amount of ECs matched (1x1)
%           *tot.org_s:    The amount of ECs matched for the organism & the
%                          substrate (1x1)
%           *tot.rest_s:   The amount of ECs matched for any organism & the
%                          substrate (1x1)
%           *tot.org_ns:   The amount of ECs matched for the organism & any
%                          substrate (1x1)
%           *tot.rest_ns:  The amount of ECs matched for any organism & any
%                          substrate (1x1)
%           *tot.org_sa:   The amount of ECs matched for the organism & 
%                          using s.a. (1x1)
%           *tot.rest_sa:  The amount of ECs matched for any organism & 
%                          using s.a. (1x1)
% 
% Benjam�n J. S�nchez. Last edited: 2016-03-01
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function kcats = matchKcats(model_data)

%Load BRENDA data:
cd ../../Databases
kcat_file = 'Saccharomyces cerevisiae_max_kCATs.txt';
fID       = fopen(kcat_file);
scan      = textscan(fID,'%s %s %f %f %f %f','delimiter','\t');
BRENDA    = [scan{1} scan{2} num2cell([scan{3} scan{5}].*3600)]; %[1/s] -> [1/h]
fclose(fID);
cd ../Matlab_Module/get_enzyme_data

%Extract relevant info from model_data:
substrates = model_data.substrates;
products   = model_data.products;
EC_numbers = model_data.EC_numbers;
model      = model_data.model;

%Create initially empty outputs:
[mM,nM]      = size(EC_numbers);
forw.kcats   = zeros(mM,nM);
forw.org_s   = zeros(mM,nM);
forw.rest_s  = zeros(mM,nM);
forw.org_ns  = zeros(mM,nM);
forw.rest_ns = zeros(mM,nM);
forw.org_sa  = zeros(mM,nM);
forw.rest_sa = zeros(mM,nM);
back.kcats   = zeros(mM,nM);
back.org_s   = zeros(mM,nM);
back.rest_s  = zeros(mM,nM);
back.org_ns  = zeros(mM,nM);
back.rest_ns = zeros(mM,nM);
back.org_sa  = zeros(mM,nM);
back.rest_sa = zeros(mM,nM);
tot.queries  = 0;
tot.org_s    = 0;
tot.rest_s   = 0;
tot.org_ns   = 0;
tot.rest_ns  = 0;
tot.org_sa   = 0;
tot.rest_sa  = 0;
tot.wc0      = 0;
tot.wc1      = 0;
tot.wc2      = 0;
tot.wc3      = 0;
tot.wc4      = 0;
tot.matrix   = zeros(6,5);

%Main loop: 
for i = 1:mM
    %Match:
    for j = 1:nM
        EC = EC_numbers{i,j};
        
        %Try to match direct reaction:
        if ~isempty(EC) && ~isempty(substrates{i,1})
            [forw,tot] = iterativeMatch(EC,substrates(i,:),i,j,BRENDA,forw,tot,model);
        end

        %Repeat for inverse reaction:
        if ~isempty(EC) && ~isempty(products{i,1})
            [back,tot] = iterativeMatch(EC,products(i,:),i,j,BRENDA,back,tot,model);
        end
    end
    %Display progress:
    disp(['Matching kcats: Ready with rxn ' num2str(i)])
end

kcats.forw = forw;
kcats.back = back;
kcats.tot  = tot;

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [dir,tot] = iterativeMatch(EC,subs,i,j,BRENDA,dir,tot,model)
%Will iteratively try to match the EC number to some registry in BRENDA,
%using each time one additional wildcard.

EC      = strsplit(EC,' ');
kcat    = zeros(size(EC));
origin  = zeros(size(EC));
matches = zeros(size(EC));
wc_num  = ones(size(EC)).*1000;
for k = 1:length(EC)
    success  = false;
    while ~success
        %Atempt match:
        [kcat(k),origin(k),matches(k)] = mainMatch(EC{k},subs,BRENDA,model,i);
        %If any match found, ends. If not, introduces one extra wild card and
        %tries again:
        if origin(k) > 0
            success   = true;
            wc_num(k) = sum(EC{k}=='-');
        else
            dot_pos  = [2 strfind(EC{k},'.')];
            wild_num = sum(EC{k}=='-');
            wc_text  = '-.-.-.-';
            EC{k}    = [EC{k}(1:dot_pos(4-wild_num)) wc_text(1:2*wild_num+1)];
        end
    end
end

if sum(origin) > 0
    %For more than one EC: Choose the maximum value among the ones with the
    %less amount of wildcards and the better origin:
    best_pos   = (wc_num == min(wc_num));
    new_origin = origin(best_pos);
    best_pos   = (origin == min(new_origin(new_origin~=0)));
    max_pos    = find(kcat == max(kcat(best_pos)));
    wc_num     = wc_num(max_pos(1));
    origin     = origin(max_pos(1));
    matches    = matches(max_pos(1));
    kcat       = kcat(max_pos(1));
    
    %Update dir and tot:
    dir.kcats(i,j)   = kcat;
    dir.org_s(i,j)   = matches*(origin == 1);
    dir.rest_s(i,j)  = matches*(origin == 2);
    dir.org_ns(i,j)  = matches*(origin == 3);
    dir.rest_ns(i,j) = matches*(origin == 4);
    dir.org_sa(i,j)  = matches*(origin == 5);
    dir.rest_sa(i,j) = matches*(origin == 6);
    tot.org_s        = tot.org_s   + (origin == 1);
    tot.rest_s       = tot.rest_s  + (origin == 2);
    tot.org_ns       = tot.org_ns  + (origin == 3);
    tot.rest_ns      = tot.rest_ns + (origin == 4);
    tot.org_sa       = tot.org_sa  + (origin == 5);
    tot.rest_sa      = tot.rest_sa + (origin == 6);
    tot.wc0          = tot.wc0     + (wc_num == 0);
    tot.wc1          = tot.wc1     + (wc_num == 1);
    tot.wc2          = tot.wc2     + (wc_num == 2);
    tot.wc3          = tot.wc3     + (wc_num == 3);
    tot.wc4          = tot.wc4     + (wc_num == 4);
    tot.queries      = tot.queries + 1;
    tot.matrix(origin,wc_num+1) = tot.matrix(origin,wc_num+1) + 1;
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [kcat,origin,matches] = mainMatch(EC,subs,BRENDA,model,i)
%Matching function prioritizing organism and substrate specificity when available.

origin = 0;
%First try to match organism and substrate:
[kcat,matches] = matchKcat(EC,subs,BRENDA,true,true,model,i);
if matches > 0
    origin = 1;

%If no match, try any organism but match the substrate:
else
    [kcat,matches] = matchKcat(EC,subs,BRENDA,false,true,model,i);
    if matches > 0
        origin = 2;
    
    %If no match, try to match organism but with any substrate:
    else
        [kcat,matches] = matchKcat(EC,subs,BRENDA,true,false,model,i);
        if matches > 0
            origin = 3;
    
        %If no match, try any organism and any substrate:
        else
            [kcat,matches] = matchKcat(EC,subs,BRENDA,false,false,model,i);
            if matches > 0
                origin = 4;
            end
        end
    end
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [kcat,matches] = matchKcat(EC,subs,BRENDA,organism,substrate,model,i)
%Will go through BRENDA and will record any match. Afterwards, it will
%return the average value and the number of matches attained.

kcat    = [];
matches = 0;

if organism
    pos = 3;
else
    pos = 4;
end

%Relaxes matching if wild cards are present:
wild     = false;
wild_pos = strfind(EC,'-');
if ~isempty(wild_pos)
    EC  = EC(1:wild_pos(1)-1);
    wild = true;
end

for k = 1:length(BRENDA)
    if strcmpi(EC,BRENDA{k,1}) || (wild && ~isempty(strfind(BRENDA{k,1},EC)))
        if substrate
            %Match substrate name:
            for l = 1:length(subs)
                j = boolean(strcmpi(model.metNames,subs{l}).*(model.S(:,i)~=0));
                if ~isempty(subs{l}) && strcmpi(subs{l},BRENDA{k,2})
                    if BRENDA{k,pos} > 0
                        kcat    = [kcat;BRENDA{k,pos}/abs(model.S(j,i))];
                        matches = matches + 1;
                    end
                end
            end
        elseif BRENDA{k,pos} > 0
            %Match with any substrate:
            kcat    = [kcat;BRENDA{k,pos}];
            matches = matches + 1;
        end
    end
end

%Return maximum value:
if isempty(kcat)
    kcat = 0;
else
    kcat = max(kcat);
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%