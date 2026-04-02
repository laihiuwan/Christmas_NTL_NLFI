import arcpy
import os
import csv
from arcpy.sa import ExtractByMask,ZonalStatisticsAsTable

root_path = r"/Users/hannahlai821/Desktop/geoprog_submit"

arcpy.env.workspace = root_path
arcpy.env.overwriteOutput = True

cities_csv = os.path.join(root_path,"cities.csv")
points_fc = os.path.join(root_path,"cities_points.shp")
buffer_fc = os.path.join(root_path,"cities_buffer_20km.shp")
out_table_dir = os.path.join(root_path,"zonal_tables")
masked_tif_dir = os.path.join(root_path,"masked_tifs")
final_csv = os.path.join(root_path,"all_cities_daily_mean.csv")

os.makedirs(out_table_dir,exist_ok=True)
os.makedirs(masked_tif_dir,exist_ok=True)

arcpy.CheckOutExtension("Spatial")

arcpy.management.XYTableToPoint(
    in_table=cities_csv,
    out_feature_class=points_fc,
    x_field="Longitude",
    y_field="Latitude",
    coordinate_system=arcpy.SpatialReference(4326)
)

arcpy.analysis.Buffer(
    in_features=points_fc,
    out_feature_class=buffer_fc,
    buffer_distance_or_field="20 Kilometers"
)

arcpy.management.JoinField(
    in_data=buffer_fc,
    in_field="ORIG_FID",
    join_table=points_fc,
    join_field="FID",
    fields=["City"]
)

with open(cities_csv,"r",encoding="utf-8-sig") as f:
    city_list = [row["City"].strip() for row in csv.DictReader(f) if row["City"].strip()]

all_results = []

arcpy.management.MakeFeatureLayer(buffer_fc,"city_layer")

for city in city_list:
    city_folder = os.path.join(root_path, city)
    tif_list = sorted([f for f in os.listdir(city_folder) if f.lower().endswith(".tif")])

    arcpy.management.SelectLayerByAttribute(
        in_layer_or_view="city_layer",
        selection_type="NEW_SELECTION",
        where_clause=f"City = '{city}'"
    )

    city_masked_dir = os.path.join(masked_tif_dir,city)
    os.makedirs(city_masked_dir,exist_ok=True)

    for tif_file in tif_list:
        tif_path = os.path.join(city_folder,tif_file)
        date_str = os.path.splitext(tif_file)[0].split("_")[-1]

        masked_tif_path = os.path.join(city_masked_dir,f"{city}_{date_str}_NTL_masked.tif")
        out_table = os.path.join(out_table_dir,f"{city}_{date_str}.dbf")

        ExtractByMask(tif_path,"city_layer").save(masked_tif_path)

        ZonalStatisticsAsTable(
            in_zone_data="city_layer",
            zone_field="City",
            in_value_raster=masked_tif_path,
            out_table=out_table,
            ignore_nodata="DATA",
            statistics_type="MEAN"
        )

        with arcpy.da.SearchCursor(out_table,["MEAN"]) as cursor:
            for row in cursor:
                all_results.append([city,date_str,row[0]])

with open(final_csv,"w",newline="",encoding="utf-8-sig") as f:
    writer = csv.writer(f)
    writer.writerow(["City","Date","MeanRad"])
    writer.writerows(all_results)

arcpy.CheckInExtension("Spatial")
print("Done")