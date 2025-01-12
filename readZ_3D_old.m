function [allData,info,units,isign] = readZ_3D(cfile,newunits)
%  Usage: [allData,info,units,isign] = readZ_3D(cfile)
%   info, units and isign are optional output arguments.
%   This information could be part of allData structure.
%   reads data from ascii impedance file, returns 
%    as cell array allData
%   There is one cell per period; each
%   cell contains all information necessary to define
%   data (locations, values, error standard dev) for
%   each period (transmitter)
% NB: assuming complex data
%  (c) Anna Kelbert, 2008

% 打开文件，并确保文件指针有效
fid = fopen(cfile, 'r');
if fid == -1
    error('无法打开文件，请检查文件路径和权限');
end

% 读取前几行的文件头内容
headerLines = 3; % 需要读取的头文件行数
record = cell(headerLines, 1); % 用于存储头文件内容

for k = 1:headerLines
    record{k} = fgetl(fid); % 使用 fgetl 逐行读取头文件
end

% 将头文件内容分配到变量
info = record{1}; % 第一行可能包含文件信息
units = record{2}; % 第二行可能包含单位信息
isign = str2double(record{3}); % 第三行可能包含符号信息，需要转为数值

% 如果存在目标单位，转换为相应单位
if nargin > 1
    SI_factor = ImpUnits(units, newunits);
    units = newunits;
else
    SI_factor = 1.0;
end


%  record # 1: number of transmitters
nTx = fscanf(fid,'%d\n',1);

for j = 1:nTx
%   for each period/mode ....

   %  record # 1 in transmitter block: period, mode, number of sites
   record = textscan(fid,'%f %d %d\n',1);
   T = record{1};
   nComp = double(record{2});
   nSites = double(record{3});

   %  record # 2 in transmitter block: site locations
   record = fscanf(fid,'%f',[nSites,3]);
   siteLoc = record;
   record = fscanf(fid,'\n');

   %  read and ignore (for now) the header of the data block
   % header = fgetl(fid);
   for k = 1:nComp
    compid{k} = fscanf(fid,'%s',1);
   end
   compChar = char(compid);

   %  records # 3 & #4 in transmitter block: data and error bars
   siteChar = '';
   for k = 1:nSites
       idx = 1:2:nComp-1;
       sites{k} = fscanf(fid,'%s',1);
       record = fscanf(fid,'%f',nComp);
       Z(k,:) = record(idx)+1i*record(idx+1);
       record = fscanf(fid,'%f',nComp);
       Zerr(k,:) = record(idx);
   end
   
   siteChar = char(sites);
   
   % convert to new units
   for i = 1:size(Z,2)
       idx = 2*i - 1;
       if ~isempty(findstr(compChar(idx,:),'Z'))
        Z(:,i) = SI_factor * Z(:,i);
        Zerr(:,i) = SI_factor * Zerr(:,i);
       end
   end

   allData{j} = struct('T',T,'Cmplx',1,'units',units,...
	'nComp',nComp,'compChar',compChar,...
    'siteLoc',siteLoc,'siteChar',siteChar,'Z',Z,'Zerr',Zerr);

   clear siteChar
end

record = textscan(fid,'%*[^:]%*c%[^\n]',1);
if ~isempty(record{1})
    origin = str2num(record{1}{1});
    if (length(origin)==3)
        for j = 1:nTx
            allData{j}.origin = [origin(1) origin(2) 0.0];
        end
    end
end

fclose(fid);
