clc;
close all;
clear;
%Include a maping object for trained classes to actual names of fruits
load('catmatch.mat');
load('db.mat');
%prompt the user for a folder containing fruits images
[FileName,PathName] = uigetfile('*.bmp','Select the testing image file');
fullFileName =[PathName,FileName];
Im    = imread(fullFileName); % read image
I     = im2double(rgb2gray(Im));        % rgb to gray
[H,W]=size(I);
I(1:floor(W/5),:)=0;
%figure();imshow(I)
%% Sobel Masking 
SM    = [-1 0 1;-2 0 2;-1 0 1];         % Sobel Vertical Mask
IS    = imfilter(I,SM,'replicate');     % Filter Image Using Sobel Mask
IS    = IS.^2;                          % Consider Just Value of Edges & Fray Weak Edges
% figure();imshow(IS)

%% Normalization
IS    = (IS-min(IS(:)))/(max(IS(:))-min(IS(:))); % Normalization
% figure();imshow(IS)
%% Threshold (Otsu)
level = graythresh(IS)/5;                 % Threshold Based on Otsu Method
IS    = im2bw(IS,level);
% figure();imshow(IS)
%% Histogram
S     = sum(IS,2);                      % Edge Horizontal Histogram
% figure();plot(1:size(S,1),S)
            % view(90,90)
            %% Plot
            % figure()
            % subplot(1,2,1);imshow(IS)
            % subplot(1,2,2);plot(1:size(S,1),S)
            % axis([1 size(IS,1) 0 max(S)]);view(90,90)
            %% Plate Location

            T1    = 0.1;                           % Threshold On Edge Histogram
            PR    = find(S > (T1*max(S)));          % Candidate Plate Rows
            %% Masked Plate
            Msk   = zeros(size(I));
            Msk(PR,:) = 1;                          % Mask
            MB    = Msk.*IS;                        % Candidate Plate (Edge Image)
%               figure();imshow(MB)
            %% Morphology (Dilation - Vertical)
            threshold0=200;flag=1;
            while(flag)
                Dy    = strel('rectangle',[2,4]);      % Vertical Extension
                MBy   = imdilate(MB,Dy);                % By Dilation
                MBy   = imfill(MBy,'holes');            % Fill Holes
                [L,num] = bwlabel(MBy);                  % Label (Binary Regions)               
                for i = 1:num                           % Compute Area Of Every Region
                [r,c,v]  = find(L == i);                % Find Indexes
                    if(sum(v)<threshold0)
                        MBy( find(L == i))=0;
                    end
                end
                if(sum(sum(MBy))==0)
                    flag=1;
                    threshold0=threshold0-50;
                    if(threshold0<0)
                        break;
                    end
                else
                    flag=0;
                end
            end
            if(flag==0)
%                figure();imshow(MBy)

            %% Morphology (Dilation - Horizontal)
            Dx    = strel('rectangle',[2,4]);      % Horizontal Extension
            MBx   = imdilate(MB,Dx);                % By Dilation
            MBx   = imfill(MBx,'holes');            % Fill Holes
%               figure();imshow(MBy)
            %% Joint Places
            BIM   = MBx.*MBy;                       % Joint Places
            % figure();imshow(BIM)
            %% Morphology (Dilation - Horizontal)
            Dy    = strel('rectangle',[1,2]);      % Horizontal Extension
            MM    = imdilate(BIM,Dy);               % By Dilation
            MM    = imfill(MM,'holes');             % Fill Holes
%              figure();imshow(MM)
            %% Erosion
            %Dr    = strel('line',10,0);             % Erosion
            %BL    = imerode(MM,Dr);
            % figure();imshow(BL)
            %% Find Biggest Binary Region (As a Plate Place)
            [L,num] = bwlabel(MM);                  % Label (Binary Regions)               
            Areas   = zeros(num,1);
            flag=1;
            threshold=1100;
            flag2=0;
            while(flag)
                for i = 1:num                           % Compute Area Of Every Region
                [r,c,v]  = find(L == i);                % Find Indexes
                Areas(i) = sum(v);                      % Compute Area    
                if(Areas(i)>threshold)
                    Areas(i)=0;
                end
                end
                if(threshold<0)
                    break;
                end
                if(isempty(Areas))
                    flag=1;
                    threshold=threshold-10;
                else
                    flag1=1;
                    while(flag1)
                        if(isempty(Areas) || sum(Areas)==0)
                            break;
                        end
                        flag2=1;
                        [jr,jc,flag1,Areas]=find_algo(L,Areas,MM);
                    end
                    if(flag1==0)
                        flag=0;
                    else
                        flag=1;
                         threshold=threshold-10;
                    end
                end 
            end
            [nRow,nCol] = size(I);
            FM      = zeros(nRow,nCol); 
            if(flag2==1)
                FM(jr,jc) = 1; 
            PL      = FM.*I;   
                              % Detected Plate
%               figure();imshow(FM)
%              figure();imshow(PL)
            %% Plot
            figure;
            imshow(Im); title('Car make and model recognition')
            hold on
            logox=floor((max(jc)+min(jc))/2);logoy=floor((max(jr)+min(jr))/2);
            plot(logox,logoy,'r*');
            hold on;
            %% ROI two lines
            Line_BW = edge(I,'sobel');
            Line_BW=imdilate(Line_BW, strel('square',1));
            %figure();imshow(Line_BW);
            hold on;
            flag=0;
            M1=max(1,logox-20);M2=min(W,logox+20);
            for i =min(H,50+logoy):-1:min(H,logoy+10)
                if(sum(Line_BW(i,M1:M2)==1)>0)
                    Bline=i;
                    flag=1;
                    break;
                end
            end
            if(flag==0)
                Bline=min(H,logoy+10);

            end
            dd=abs(Bline-logoy);
            Fline=max(floor(logoy*0.8),logoy-floor(dd*3.5));
            % bm=30;um=50;
            RL=80;
            if(logox-W/2>0)
                RL=-80;
            end
            Fflag=0;
            w1=logox+RL;
            Options.upright=true;
            Options.tresh=0.0001;
            if(w1>logox)
                Ipts=OpenSurf(Im(Fline:Bline,logox:w1),Options);
                if(numel(fieldnames(Ipts))>0)
                    Fflag=1;
                    xx=[logox;w1];
                    yy=[Fline;Fline];
                    simage=Im(Fline:Bline,logox:w1);
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     hold on;
%                     yy=[Bline;Bline];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     Mline=floor((Fline+Bline)/2);
%                     yy=[Mline;Mline];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     xx=[logox;logox];
%                     yy=[Fline;Bline];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     xx=[w1;w1];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     xx=[logox+floor((w1-logox)/2);logox+floor((w1-logox)/2)];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     for nn=1:length(Ipts)
%                         plot(Ipts(nn).x+logox,Ipts(nn).y+Fline,'b*');
%                         feature_vector=[feature_vector;Ipts(nn).descriptor'];feature_label=[feature_label,fnum];
%                         hold on;
%                     end
                end
            else
                Ipts=OpenSurf(Im(Fline:Bline,w1:logox),Options);
                if(numel(fieldnames(Ipts))>0)
                    Fflag=1;
                    simage=Im(Fline:Bline,w1:logox);
%                     xx=[w1;logox];
%                     yy=[Fline;Fline];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     hold on;
%                     yy=[Bline;Bline];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     Mline=floor((Fline+Bline)/2);
%                     yy=[Mline;Mline];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     xx=[logox;logox];
%                     yy=[Fline;Bline];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     xx=[w1;w1];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
%                     xx=[w1+floor((-w1+logox)/2);w1+floor((-w1+logox)/2)];
%                     plot(xx,yy,'LineWidth',2,'Color','green');
                    
                end
            end
            if(Fflag==1)
                simage=imresize(simage,[40,80]);
                img = simage;
                labelIdx = predict(categoryClassifier, img);
                itemName = categoryClassifier.Labels{labelIdx};
                fprintf('%s - %s\n', FileName,mapObj(itemName));
            end
            end
            
            end
             

