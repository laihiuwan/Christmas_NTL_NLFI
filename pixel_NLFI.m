clc;clear;close all;

root_path = '/Users/hannahlai821/Desktop/geoprog_submit/masked_tifs';
city_name = 'Houston';
city_folder = fullfile(root_path,city_name);

tif_info = dir(fullfile(city_folder,'*.tif'));
num_files = length(tif_info);

first_file = fullfile(city_folder,tif_info(1).name);
[img,R] = readgeoraster(first_file);
img = double(img);

[row,col] = size(img);
num_pixels = row*col;

stack = nan(row,col,num_files);

for i=1:num_files
    file_path = fullfile(city_folder,tif_info(i).name);
    img = double(readgeoraster(file_path));
    img(img<0.5) = nan;
    stack(:,:,i) = img;
end

time_stack = reshape(stack,num_pixels,num_files);

pix_mean = mean(time_stack,2,'omitnan');
pix_std = std(time_stack,0,2,'omitnan');
valid_counts = sum(~isnan(time_stack),2);

pix_cv = pix_std ./ pix_mean;
pix_cv(pix_mean==0) = nan;

pix_slope = nan(num_pixels,1);
pix_kurt = nan(num_pixels,1);

t = (1:num_files)';

for i = 1:num_pixels
    if valid_counts(i) >= ceil(0.8*num_files)
        y = time_stack(i,:)';
        idx = ~isnan(y);
        p = polyfit(t(idx),y(idx),1);
        pix_slope(i) = p(1);
        pix_kurt(i) = kurtosis(y(idx));
    end
end

valid_idx = valid_counts>=ceil(0.8*num_files) & pix_mean>=0.5 & ~isnan(pix_std) & ~isnan(pix_cv);

cv_threshold = prctile(pix_cv(valid_idx),30);
slope_threshold = 0.05;
kurt_threshold = 4;

stable_idx = valid_idx & pix_cv<=cv_threshold & abs(pix_slope)<=slope_threshold & pix_kurt<=kurt_threshold;

stable_mean = pix_mean(stable_idx);
stable_std = pix_std(stable_idx);

p = polyfit(stable_mean,stable_std,1);
slope_value = p(1);
intercept_value = p(2);

expected_std = nan(num_pixels,1);
expected_std(valid_idx) = slope_value * pix_mean(valid_idx) + intercept_value;
expected_std(expected_std<0) = nan;

pix_nlfi = nan(num_pixels, 1);
idx = valid_idx & ~isnan(expected_std);
pix_nlfi(idx) = abs(slope_value * pix_mean(idx) - pix_std(idx) + intercept_value) ./ sqrt(slope_value^2 + 1);

nlfi_image = reshape(pix_nlfi,row,col);

output_folder = fullfile('/Users/hannahlai821/Desktop/geoprog_submit',[city_name '_NLFI']);

if ~exist(output_folder,'dir')
    mkdir(output_folder);
end

geotiffwrite(fullfile(output_folder,[city_name '_nlfi.tif']),nlfi_image,R);

baseline_days = 1:15;
christmas_days = 21:26;
baseline_mean_pix = mean(time_stack(:,baseline_days),2,'omitnan');
christmas_mean_pix = mean(time_stack(:,christmas_days),2,'omitnan');

holiday_effect_pix = ((christmas_mean_pix - baseline_mean_pix) ./ baseline_mean_pix) * 100;
holiday_effect_pix(baseline_mean_pix<0.5) = nan;
holiday_effect_pix(isnan(baseline_mean_pix)) = nan;

holiday_effect_map = reshape(holiday_effect_pix,row,col);

geotiffwrite(fullfile(output_folder,[city_name '_christmas_effect.tif']),holiday_effect_map,R);

x_line = linspace(0,max(pix_mean(valid_idx),[],'omitnan'),300);
y_line = polyval(p,x_line);

figure,hold on,
h1 = scatter(pix_mean(valid_idx),pix_std(valid_idx),8,[0.9608,0.7804,0.5569],'filled');
h2 = scatter(pix_mean(stable_idx),pix_std(stable_idx),8,[0.6706,0.2510,0.2588],'filled');
h3 = plot(x_line,y_line,'Color',[0.2902,0.4863,1.0000],'LineStyle','--','LineWidth',2);
xlabel('Pixel Mean NTL')
ylabel('Pixel Std of NTL')
title(['Expected Variation: ',city_name])
legend([h1,h2,h3],{'Valid pixels','Stable pixels','Expected variability'},'Location','best')
grid on

figure,
subplot(1,2,1),
imagesc(nlfi_image);axis image off;colorbar;clim([0,250]);
colormap('turbo');
title(['NLFI: ',city_name]);

subplot(1,2,2),
imagesc(holiday_effect_map);axis image off;colorbar;clim([-50,50]);
title(['Christmas Effect (%): ',city_name]);

both_valid = valid_idx & ~isnan(holiday_effect_pix) & ~isnan(pix_nlfi);
nlfi_scatter = pix_nlfi(both_valid);
effect_scatter = holiday_effect_pix(both_valid);

r_value = corr(nlfi_scatter,effect_scatter,'rows','complete');

figure,hold on,
scatter(nlfi_scatter,effect_scatter,5,[0.2902, 0.4863, 1.0000],'filled','MarkerFaceAlpha',0.3);
p = polyfit(nlfi_scatter,effect_scatter,1);
x_fit = linspace(min(nlfi_scatter),max(nlfi_scatter),300);
y_fit = polyval(p,x_fit);
plot(x_fit,y_fit,'--','LineWidth',2,'Color',[0.9098, 0.5725, 0.2471]);
xlabel('NLFI');
ylabel('Christmas Effect (%)');
title(sprintf('%s: NLFI vs Christmas Effect (r = %.3f)',city_name,r_value));
grid on;

fprintf('City: %s\n',city_name);
fprintf('Days used: %d\n',num_files);
fprintf('Total pixels: %d\n',num_pixels);
fprintf('Valid pixels: %d\n',sum(valid_idx));
fprintf('Stable pixels: %d\n',sum(stable_idx));
fprintf('CV threshold: %.4f\n',cv_threshold);
fprintf('Expected variation line: std = %.4f * mean + %.4f\n',slope_value,intercept_value);
fprintf('Mean Christmas Effect: %.2f%%\n',mean(holiday_effect_pix,'omitnan'));