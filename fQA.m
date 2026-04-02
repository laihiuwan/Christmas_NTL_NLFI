function [y_raw,y_clean,y_smooth] = fQA(y)

    y_raw = double(y(:));
    y_clean = y_raw;

    if isempty(y_clean)
        y_smooth = y_clean;
        return
    end

    y_clean(~isfinite(y_clean) | y_clean<=0) = nan;

    meanVal = mean(y_clean,'omitnan');
    stdVal = std(y_clean,'omitnan');

    if ~isnan(stdVal) && stdVal > 0
        outlierIdx = abs(y_clean-meanVal) > 3*stdVal;
        y_clean(outlierIdx) = nan;
    end

    y_clean = fillmissing(y_clean,'movmedian',5);
    y_med = medfilt1(y_clean,5,'omitnan','truncate');
    y_smooth = movmean(y_med,3,'omitnan');

end
