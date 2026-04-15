clc;clear;close all;

file_path = "C:\Users\hannahlhw\OneDrive - The Chinese University of Hong Kong\Desktop\Christmas_NTL_NLFI\all_cities_daily_mean.csv";
T = readtable(file_path);

date_text = string(T.Date);
date_value = datetime(date_text,'InputFormat','yyyyMMdd');
T.DateTime = date_value;
T = sortrows(T,{'City','DateTime'});

us_cities = ["Los_Angeles","Phoenix","Houston","Miami","Las_Vegas"];
china_cities = ["Shanghai","Guangzhou","Shenzhen","Chengdu","Hangzhou"];
all_cities = [us_cities,china_cities];

baseline_start = datetime('2019-12-01','InputFormat','yyyy-MM-dd');
baseline_end = datetime('2019-12-15','InputFormat','yyyy-MM-dd');

christmas_start = datetime('2019-12-21','InputFormat','yyyy-MM-dd');
christmas_end = datetime('2019-12-26','InputFormat','yyyy-MM-dd');

december_start = datetime('2019-12-01','InputFormat','yyyy-MM-dd');
december_end = datetime('2019-12-31','InputFormat','yyyy-MM-dd');

num_cities = length(all_cities);

Country = strings(num_cities,1);
City = strings(num_cities,1);

Mean_Dec_NTL = nan(num_cities,1);
Baseline_Mean = nan(num_cities,1);
Christmas_Mean = nan(num_cities,1);
difference_value = nan(num_cities,1);
Holiday_Effect_Pct = nan(num_cities,1);
Instability = nan(num_cities,1);

for i=1:num_cities

    City(i) = all_cities(i);
    idx_city = strcmp(T.City,City(i));
    city_data = T(idx_city,:);
    x = city_data.DateTime;
    y = city_data.MeanRad;
    [y_raw,y_clean,y_smooth] = fQA(y);

    is_us_city = false;
    for j=1:length(us_cities)
        if strcmp(City(i),us_cities(j))
            is_us_city = true;
        end
    end

    if is_us_city == true
        Country(i) = "USA";
    else
        Country(i) = "China";
    end

    idx_dec = (x >= december_start) & (x <= december_end);
    dec_data = y_clean(idx_dec);
    Mean_Dec_NTL(i) = mean(dec_data,'omitnan');

    idx_baseline = (x >= baseline_start) & (x <= baseline_end);
    baseline_data = y_clean(idx_baseline);
    Baseline_Mean(i) = mean(baseline_data,'omitnan');

    idx_christmas = (x >= christmas_start) & (x <= christmas_end);
    christmas_data = y_clean(idx_christmas);
    Christmas_Mean(i) = mean(christmas_data,'omitnan');
    
    difference_value(i) = Christmas_Mean(i) - Baseline_Mean(i);

    if ~isnan(Baseline_Mean(i)) && Baseline_Mean(i) ~= 0
        Holiday_Effect_Pct(i) = (difference_value(i) / Baseline_Mean(i)) * 100;
    else
        Holiday_Effect_Pct(i) = nan;
    end

    Instability(i) = std(dec_data,'omitnan');

    figure
    h1 = plot(x,y_raw,'.-','Color',[0.800,0.600,0.004],'LineWidth',1);
    hold on
    h2 = plot(x,y_smooth,'Color',[0.000,0.361,0.004],'LineWidth',2);
    xline1 = xline(baseline_start,'Color',[0.000,0.129,0.278],'LineStyle','--','LineWidth',1);
    xline(baseline_end,'Color',[0.000,0.129,0.278],'LineStyle','--','LineWidth',1);
    xline2 = xline(christmas_start,'Color',[0.718,0.000,0.094],'LineStyle','-.','LineWidth',2);
    xline(christmas_end,'Color',[0.718,0.000,0.094],'LineStyle','-.','LineWidth',2);
    xlabel('Date')
    ylabel('Mean NTL')
    title(['Daily Nighttime Light in December 2019: ',char(City(i))])
    legend([h1,h2,xline1,xline2],{'Raw NTL','Smoothed NTL','Baseline','Christmas'}, 'Location','best')
    grid on

end

figure,
hBar = bar(1:num_cities,Holiday_Effect_Pct);
hBar.FaceColor = 'flat';
for k=1:num_cities
    if k<=5
        hBar.CData(k,:) = [0.718,0.000,0.094];
    else
        hBar.CData(k,:) = [0.000,0.361,0.004];
    end
end
set(gca,'XTick',1:num_cities)
set(gca,'XTickLabel',cellstr(City))
xtickangle(45)
xlabel('City')
ylabel('Holiday Effect (%)')
title('Christmas Holiday Effect by City')
grid on
