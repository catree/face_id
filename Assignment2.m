% Image and Visual Computing Assignment 2: Face Verification & Recognition
%==========================================================================
%   In this assignment, you are expected to use the previous learned method
%   to cope with face recognition and verification problem. The vl_feat, 
%   libsvm, liblinear and any other classification and feature extraction 
%   library are allowed to use in this assignment. The built-in matlab 
%   object-detection functionis not allowed. Good luck and have fun!
%
%                                               Released Date:   31/10/2017
%==========================================================================

%% Initialisation
%==========================================================================
% Add the path of used library.
% - The function of adding path of liblinear and vlfeat is included.
%==========================================================================
clear all
clc
run ICV_setup

% Hyperparameter of experiments
resize_size=[64 64];


%% Part I: Face Recognition: Who is it?
%==========================================================================
% The aim of this task is to recognize the person in the image(who is he).
% We train a multiclass classifer to recognize who is the person in this
% image.
% - Propose the patches of the images
% - Recognize the person (multiclass)
%==========================================================================


disp('Recognition :Extracting features..')

Xtr = []; Ytr = [];
Xva = []; Yva = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Loading the training data
% -tr_img_sample/va_img_sample:
% The data is store in a N-by-3 cell array. The first dimension of the cell
% array is the cropped face images. The second dimension is the name of the
% image and the third dimension is the class label for each image.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

load('./data/face_recognition/face_recognition_data_tr.mat')

cellSize = 8;

imset = imageSet('data/face_recognition/images/', 'recursive');
       
bag = bagOfFeatures(imset, 'VocabularySize', 250);


Ytr2 = zeros(368, 35);
A = {};

for i =1:length(tr_img_sample)
    temp = single(tr_img_sample{i,1})/255;
    
    foldername = strsplit(tr_img_sample{i,2}, '_');
    foldername = ['data/face_recognition/images/', foldername{1}, '_', foldername{2}];
    mkdir(foldername);
    imwrite(temp, [foldername, '/', tr_img_sample{i,2}, '.png']);
    
    img = imread([foldername, '/', tr_img_sample{i,2}, '.png']);
    featureVector = encode(bag, img);
    
    
%     Xtr = [Xtr;temp(:)'];
%     A{end+1} = temp;

    hog = vl_hog(temp, cellSize);
    lbp = vl_lbp(temp, cellSize);
    Xtr = [Xtr;[hog(:);lbp(:);featureVector(:)]'];
%     Xtr = [Xtr;lbp(:)'];

%     temp2 = zeros(35);
%     temp2(tr_img_sample{i,3}) = 1;
%     Ytr = [Ytr;temp2];
%     Ytr2(i, tr_img_sample{i,3}) = 1;
    Ytr = [Ytr;tr_img_sample{i,3}];
end


load('./data/face_recognition/face_recognition_data_va.mat')

% Yva = zeros(111, 35);

B = {};

for i =1:length(va_img_sample)
    temp = single(va_img_sample{i,1})/255;
    
    foldername = strsplit(va_img_sample{i,2}, '_');
    foldername = ['data/face_recognition/val_images/', foldername{1}, '_', foldername{2}];
    mkdir(foldername);
    imwrite(temp, [foldername, '/', va_img_sample{i,2}, '.png']);
    
    img = imread([foldername, '/', va_img_sample{i,2}, '.png']);
    featureVector = encode(bag, img);

%     Xva = [Xva;temp(:)'];
%     B{end+1} = temp;

    hog = vl_hog(temp, cellSize);
    lbp = vl_lbp(temp, cellSize);
    Xva = [Xva;[hog(:);lbp(:);featureVector(:) ]'];
%     Xva = [Xva;lbp(:)'];
%     Yva(i, tr_img_sample{i,3}) = 1;
    Yva = [Yva;va_img_sample{i,3}];
end



% Xdata = cat(1, Xtr, Xva);
% Ydata = cat(1, Ytr, Yva);

[coeff,score,latent,~,explained] = pca(Xtr,'NumComponents',200);
Xcentered = score*coeff';

Xtr = bsxfun(@minus,Xtr,mean(Xtr));
Xva = bsxfun(@minus,Xva,mean(Xva));

Xtr = score;
Xva = Xva*coeff;

% biplot(coeff(:,1:2),'scores',score(:,1:2),'varlabels',{'v_1','v_2','v_3','v_4'});

disp('Finished feature extraction.')

%%

% imset = imageSet('data/face_recognition/images/', 'recursive');
% 
% bag = bagOfFeatures(imset, 'VocabularySize', 250, 'PointSelection', 'Grid', 'GridStep', [8,8], 'BlockWidth', [32 64 96 128]);

% categoryClassifier = trainImageCategoryClassifier(imset, bag);
% 
% confMatrix = evaluate(categoryClassifier, imset);
% 
% mean(diag(confMatrix));
% 
% val_imset = imageSet('data/face_recognition/val_images/', 'recursive');
% 
% [l, scores] = predict(categoryClassifier, val_imset);
% 
% acc = mean(l==Yva)*100;
% 
% fprintf('The accuracy of face recognition is:%.2f \n', acc)


%%

rng('default')
hiddenSize1 = 64;

autoenc1 = trainAutoencoder(A,hiddenSize1, ...
    'MaxEpochs',400, ...
    'L2WeightRegularization',0.004, ...
    'SparsityRegularization',4, ...
    'SparsityProportion',0.15, ...
    'ScaleData', false, ...
    'UseGPU',true);

view(autoenc1)
figure()
plotWeights(autoenc1);


feat1 = encode(autoenc1,A);

%%

hiddenSize2 = 50;
autoenc2 = trainAutoencoder(feat1,hiddenSize2, ...
    'MaxEpochs',100, ...
    'L2WeightRegularization',0.002, ...
    'SparsityRegularization',4, ...
    'SparsityProportion',0.1, ...
    'ScaleData', false);

view(autoenc2)
feat2 = encode(autoenc2,feat1);

%%

softnet = trainSoftmaxLayer(feat2,Ytr2','MaxEpochs',400);

view(softnet)

%%

deepnet = stack(autoenc1,autoenc2,softnet);
view(deepnet)

%%

xTest = zeros(4096,numel(B));
for i = 1:numel(B)
    xTest(:,i) = B{i}(:);
end

%%

y = deepnet(xTest);
plotconfusion(Yva',y);

%% Train the recognizer and evaluate the performance
Xtr = double(Xtr);
Xva = double(Xva);

% Train the recognizer
% model = fitcknn(Xtr,Ytr,'NumNeighbors',3);
% [l,prob] = predict(model,Xva);

%model = trainImageCategoryClassifier(imset, bag)
%[l,prob] = predict(model, Xva);

%evaluate(model, val_imset)

% p = encode(autoenc1,B);
% 
% model = fitcecoc(feat1',Ytr);
% [l,prob] = predict(model,p');

model = fitcecoc(Xtr, Ytr);
[l,prob] = predict(model, Xva);

%model = fitcsvm(Xtr,Ytr);
%[l,prob] = predict(model,Xva);

% Compute the accuracy
acc = mean(l==Yva)*100;

fprintf('The accuracy of face recognition is:%.2f \n', acc)
% Check your result on the raw images and try to analyse the limits of the
% current method.

return




%% Visualization the result of face recognition

data_idx = [1,30,50]; % The index of image in validation set
nSample = 3; % number of visualize data. maximum should be 3
% nPairs = length(data_idx); % unconment to get full size of 
visualise_recognition(va_img_sample,prob,Yva,data_idx,nSample )


%% Part II: Face Verification: 
%==========================================================================
% The aim of this task is to verify whether the two given people in the
% images are the same person. We train a binary classifier to predict
% whether these two people are actually the same person or not.
% - Extract the features
% - Get a data representation for training
% - Train the verifier and evaluate its performance
%==========================================================================


disp('Verification:Extracting features..')


Xtr = [];
Xva = [];
load('./data/face_verification/face_verification_tr.mat')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Loading the training data
% -tr_img_pair/va_img_pair:
% The data is store in a N-by-4 cell array. The first dimension of the cell
% array is the first cropped face images. The second dimension is the name 
% of the image. Similarly, the third dimension is another image and the
% fourth dimension is the name of that image.
% -Ytr/Yva: is the label of 'same' or 'different'
%%%%%%%%%%%%%%%%%

Ytr2 = zeros(1800,2);

% You should construct the features in here. (read, resize, extract)
for i =1:length(tr_img_pair)
%     foldername = ['data/face_verification/images/', num2str(i)];
%     mkdir(foldername);
%     imwrite(tr_img_pair{i,1}, [foldername, '/', tr_img_pair{i,2}, '.png']);
%     imwrite(tr_img_pair{i,3}, [foldername, '/', tr_img_pair{i,4}, '.png']);

    temp = single(tr_img_pair{i,1})/255;
    
    temp = vl_lbp(temp, cellSize);
    temp_Xtr1 = temp(:)';
    
    temp = single(tr_img_pair{i,3})/255;
    
    temp = vl_lbp(temp, cellSize);
    temp_Xtr2 = temp(:)';
    
    index = min(Ytr(i) + 2, 2)
    Ytr2(i, index) = 1;
    
    Xtr = [Xtr;temp_Xtr1-temp_Xtr2];
end


% BoW visual representation (Or any other better representation)


load('./data/face_verification/face_verification_va.mat')
for i =1:length(va_img_pair)
    temp = single(va_img_pair{i,1})/255;
    temp = vl_lbp(temp, cellSize);
    temp_Xva1 = temp(:)';
    
    temp = single(va_img_pair{i,3})/255;
    temp = vl_lbp(temp, cellSize);
    temp_Xva2 = temp(:)';
    
    Xva = [Xva;temp_Xva1-temp_Xva2];
end

%% Train the verifier and evaluate the performance
Xtr = double(Xtr);
Xva = double(Xva);


% Train the recognizer and evaluate the performance
%model = fitcknn(Xtr,Ytr,'NumNeighbors',3);
%[l,prob] = predict(model,Xva);

model = fitcecoc(Xtr,Ytr);
[l,prob] = predict(model,Xva);

% Compute the accuracy
acc = mean(l==Yva)*100;

fprintf('The accuracy of face recognition is:%.2f \n', acc)



%% Visualization the result of face verification

data_idx = [100,200,300]; % The index of image in validation set
nPairs = 3; % number of visualize data. maximum is 3
% nPairs = length(data_idx); 
visualise_verification(va_img_pair,prob,Yva,data_idx,nPairs )