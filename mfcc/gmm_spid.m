clc;
clear all;
close all;
%%
addpath('..');
addpath('../CHINESE(MANDARIN)');
addpath('../vad');
addpath('../vad/models');
addpath('../vad/mfiles');
%%
%Training-Phase
Tw=30;%window-length
Ts=10;%shift
alpha=0.97;
M=20;
C=12;
K=64;
L=22;
Fs=8000;
LF=300;
HF=3700;
%%
% [speech,fs]=wavread('Capture');
% speech=resample(speech(1:160000,1),Fs,fs);
% vadout=apply_vad(speech,0.1,20);
% [MFCCs,FBEs,frames]=mfcc(speech,Fs,Tw,Ts,alpha,@hamming,[LF,HF],M,C+1,L);
% VadFlag=vadout(1:min(length(MFCCs),length(vadout)));
% index=find(VadFlag~=0);
fid=fopen('mfccs','rb');
MFCCs=fread(fid,'double');
fclose(fid);
MFCCs=reshape(MFCCs,13,2048);
[fbes,W]=ica_signal(MFCCs(2:C+1,:),C,1);
[Priors,Mu,Sigma]=EM_init_kmeans(fbes,K);
[Priors,Mu,Sigma]=EM(fbes,Priors,Mu,Sigma);
%%
[speech1,fs]=wavread('Ch_m2');
speech1=resample(speech1,Fs,fs);
vadout=apply_vad(speech1,0.1,20);
[MFCCs1,FBEs1,frames1]=mfcc(speech1,Fs,Tw,Ts,alpha,@hamming,[LF,HF],M,C+1,L);
VadFlag=vadout(1:min(length(MFCCs1),length(vadout)));
index=find(VadFlag~=0);
MFCCs1=MFCCs1(2:end,index)-repmat(mean(MFCCs1(2:end,index),2),1,size(MFCCs1(2:end,index),2));
MFCCs1=MFCCs1./repmat(std(MFCCs1,1,2),1,size(MFCCs1,2));
[fbes1,W1]=ica_signal(MFCCs1,C,1);
[Priors1,Mu1,Sigma1]=EM_init_kmeans(fbes1,K);
[Priors1,Mu1,Sigma1]=EM(fbes1,Priors1,Mu1,Sigma1);
%%
[speech2,fs]=wavread('Ch_m3');
speech2=resample(speech2,Fs,fs);
vadout=apply_vad(speech2,0.1,20);
[MFCCs2,FBEs2,frames2]=mfcc(speech2,Fs,Tw,Ts,alpha,@hamming,[LF,HF],M,C+1,L);
VadFlag=vadout(1:min(length(MFCCs2),length(vadout)));
index=find(VadFlag~=0);
MFCCs2=MFCCs2(2:end,index)-repmat(mean(MFCCs2(2:end,index),2),1,size(MFCCs2(2:end,index),2));
MFCCs2=MFCCs2./repmat(std(MFCCs2,1,2),1,size(MFCCs2,2));
[fbes2,W2]=ica_signal(MFCCs2,C,1);
[Priors2,Mu2,Sigma2]=EM_init_kmeans(fbes2,K);
[Priors2,Mu2,Sigma2]=EM(fbes2,Priors2,Mu2,Sigma2);
%%
%Test-Phase
[speech3,fs]=wavread('Ch_m1');
speech3=resample(speech3,Fs,fs);
speech3=awgn(speech3,30,'measured');
ISM_RIR_bank(my_ISM_setup_iv,'ISM_RIRs_iv.mat');
AuData_s1=ISM_AudioData('ISM_RIRs_iv.mat',speech3);
vadout=apply_vad(AuData_s1(:,1),0.1,20);
[MFCCs3,FBEs3,frames3]=mfcc(AuData_s1(:,1),Fs,Tw,Ts,alpha,@hamming,[LF,HF],M,C+1,L);
VadFlag=vadout(1:min(length(MFCCs3),length(vadout)));
index=find(VadFlag~=0);
MFCCs3=MFCCs3(2:end,index)-repmat(mean(MFCCs3(2:end,index),2),1,size(MFCCs3(2:end,index),2));
MFCCs3=MFCCs3./repmat(std(MFCCs3,1,2),1,size(MFCCs3,2));
fbes3=W*MFCCs3;
fbes4=W1*MFCCs3;
fbes5=W2*MFCCs3;%exp[-(x1-u1)'*inv(cov)*(x1-u1)/2]
P=zeros(size(MFCCs3,2),K,3);
for m=1:1:K,
    P(:,m,1)=Priors(m)*gaussPDF(fbes3,Mu(:,m),Sigma(:,:,m));%exp(-(x-u)*inv(cov)*(x-u)'/2)
end
for m=1:1:K,
    P(:,m,2)=Priors1(m)*gaussPDF(fbes4,Mu1(:,m),Sigma1(:,:,m));
end
for m=1:1:K,
    P(:,m,3)=Priors2(m)*gaussPDF(fbes5,Mu2(:,m),Sigma2(:,:,m));
end
p=zeros(size(MFCCs3,2),3);
p(1,1)=log(sum(P(1,:,1),2));
p(1,2)=log(sum(P(1,:,2),2));
p(1,3)=log(sum(P(1,:,3),2));
for k=2:1:size(MFCCs3,2),
    p(k,1)=p(k-1,1)+log(sum(P(k,:,1),2));
    p(k,2)=p(k-1,2)+log(sum(P(k,:,2),2));
    p(k,3)=p(k-1,3)+log(sum(P(k,:,3),2));
end
p=p/length(p);
