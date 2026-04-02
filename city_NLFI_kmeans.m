clc;clear;close all;

root_path = '/Users/hannahlai821/Desktop/geoprog_submit/masked_tifs';

us_cities = ["Los_Angeles","Phoenix","Houston","Miami","Las_Vegas"];
china_cities = ["Shanghai","Guangzhou","Shenzhen","Chengdu","Hangzhou"];
all_cities = [us_cities,china_cities];

num_cities = length(all_cities);

Country = strings(num_cities,1);
City = strings(num_cities,1);

City_NLFI = nan(num_cities,1);
Christmas_Effect = nan(num_cities,1);
Mean_Dec_NTL = nan(num_cities,1);
Instability = nan(num_cities,1);

for c = 1:num_cities

    city_name = all_cities(c);
    City(c) = city_name;

    if any(strcmp(city_name,us_cities))
        Country(c) = "USA";
    else
        Country(c) = "China";
    end

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

    for i=1:num_pixels
        if valid_counts(i) >= ceil(0.8*num_files)
            y = time_stack(i,:)';
            idx = ~isnan(y);
            p = polyfit(t(idx),y(idx),1);
            pix_slope(i) = p(1);
            pix_kurt(i) = kurtosis(y(idx));
        end
    end

    valid_idx = valid_counts >= ceil(0.8*num_files) & pix_mean >= 0.5 & ~isnan(pix_std) & ~isnan(pix_cv);

    cv_threshold = prctile(pix_cv(valid_idx),30);
    slope_threshold = 0.05;
    kurt_threshold = 4;

    stable_idx = valid_idx & pix_cv <= cv_threshold & abs(pix_slope) <= slope_threshold & pix_kurt <= kurt_threshold;

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

    City_NLFI(c) = mean(pix_nlfi,'omitnan');

    baseline_days = 1:15;
    christmas_days = 21:26;
    baseline_mean_pix = mean(time_stack(:,baseline_days),2,'omitnan');
    christmas_mean_pix = mean(time_stack(:,christmas_days),2,'omitnan');

    holiday_effect_pix = ((christmas_mean_pix - baseline_mean_pix) ./ baseline_mean_pix) * 100;
    holiday_effect_pix(baseline_mean_pix<0.5) = nan;
    holiday_effect_pix(isnan(baseline_mean_pix)) = nan;

    Christmas_Effect(c) = mean(holiday_effect_pix,'omitnan');

    dec_data = mean(time_stack,2,'omitnan');
    Mean_Dec_NTL(c) = mean(dec_data,'omitnan');
    Instability(c) = std(dec_data,'omitnan');

end

valid_cities = ~isnan(City_NLFI) & ~isnan(Christmas_Effect);

City = City(valid_cities);
Country = Country(valid_cities);
City_NLFI = City_NLFI(valid_cities);
Christmas_Effect = Christmas_Effect(valid_cities);
Mean_Dec_NTL = Mean_Dec_NTL(valid_cities);
Instability = Instability(valid_cities);

num_cities = length(City);

X = [City_NLFI,Christmas_Effect];
X_norm = zscore(X);

[idx,C] = kmeans(X_norm,3,'Replicates',50);

figure,hold on,

cluster_colors = [0.000,0.361,0.004;0.718,0.000,0.094;0.800,0.600,0.004];

for i=1:num_cities
    if strcmp(Country(i),'USA')
        marker_shape = 'o';
    else
        marker_shape = 's';
    end
    scatter(City_NLFI(i),Christmas_Effect(i),120,cluster_colors(idx(i),:),marker_shape,'filled');
    text(City_NLFI(i),Christmas_Effect(i),['  ' char(City(i))],'FontSize',9,'Interpreter','none');
end

xlabel('City-Level NLFI');
ylabel('Christmas Effect (%)');
title('K-means Clustering: NLFI vs Christmas Effect');
grid on
hold off