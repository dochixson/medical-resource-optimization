*------------------------------------------------------------------------------*
| Program: cc_forecast_accuracy_standalone - SAS INTERNAL ONLY!
| 
|    
|*--------------------------------------------------------------------------------* ;


/* Start cas session */
cas mysess;
caslib _all_ assign;

/* Point to the code */
%let my_code_path=/r/sanyo.unx.sas.com/vol/vol920/u92/navikt/casuser/covid/code/MRO/git;
%include "&my_code_path./cc_forecast_demand.sas";
%include "&my_code_path./cc_med_res_opt.sas";
%include "&my_code_path./cc_data_prep.sas";

/* Define libraries */
%let inlib=cc;
%let outlib=cc;
%let _worklib=casuser;

/* Submit code */
%cc_data_prep(
    inlib=&inlib
    ,outlib=&outlib
    ,input_utilization=input_utilization
    ,input_capacity=input_capacity
    ,input_financials=input_financials
    ,input_service_attributes=input_service_attributes
    ,input_demand=input_demand
    ,input_opt_parameters=input_opt_parameters
/*
    ,include_str=%str(facility in ('Hillcrest','ALL') )
*/
    ,exclude_str=%str(facility in ('Florida','CCCHR') or service_line='Evaluation and Management')
    ,los_rounding_threshold=0.5
    ,output_hierarchy_mismatch=output_dp_hierarchy_mismatch
    ,output_resource_mismatch=output_dp_resource_mismatch
    ,output_invalid_values=output_dp_invalid_values
    ,output_duplicate_rows=output_dp_duplicate_rows
    ,_worklib=&_worklib
    ,_debug=0
    );

proc sql;
  select max(date) into: max_date from &_worklib..input_demand_pp;
quit;

data &_worklib..input_demand_train &_worklib..input_demand_test;
   set &_worklib..input_demand_pp;
   if date <= (&max_date. - 30) then output &_worklib..input_demand_train;
   else output &_worklib..input_demand_test;
run;

%cc_forecast_demand(
    inlib=&inlib
    ,outlib=&outlib.
	,input_demand = input_demand_train
	,output_fd_demand_fcst=output_fd_demand_fcst
	,lead_weeks=26
	,forecast_model = tsmdl
    ,_worklib=casuser
    ,_debug=0
    );

%let hierarchy=%str(facility service_line sub_service ip_op_indicator med_surg_indicator);
proc delete data=&outlib..output_fa_fit_fcst;
run;
data &outlib..output_fa_fit_fcst (promote=yes);
	merge 
		&outlib..output_fd_demand_fcst (in=a keep = &hierarchy. predict_date daily_predict rename = (predict_date=date))
		&_worklib..input_demand_pp (in=b keep = &hierarchy. date demand);
	by &hierarchy. date;
	if b;
run;

data &_worklib.._tmp_fcst;
	format date date9.;
	format week_start_date date9.;
	set &outlib..output_fa_fit_fcst;
	if daily_predict~=.;
	if demand ~=.;
	  week_num=week(date);
      year_num=year(date);
      week_start_date=input(put(year_num, 4.)||"W"||put(week_num,z2.)||"01", weekv9.);
run;

proc cas;
 	  aggregation.aggregate / table={caslib="&_worklib.", name="_tmp_fcst"
		groupby={"facility","service_line","sub_service","ip_op_indicator","week_start_date"}} 
		saveGroupByFormat=false 
 	     varSpecs={{name="daily_predict", summarySubset="Sum", columnNames="Total_Fcst"}
			 	   {name="demand", summarySubset="Sum", columnNames="Total_Demand"}} 		   	  	
     
 	     casOut={caslib="&_worklib.",name="_tmp_fa_agg",replace=true}; run; 
quit;

data &_worklib.._tmp_fa_ape;
	set &_worklib.._tmp_fa_agg;
	ape=abs(Total_Demand-Total_Fcst)/Total_Demand;
run;

proc cas;
 	  aggregation.aggregate / table={caslib="&_worklib.", name="_tmp_fa_ape"
		groupby={"facility","service_line","ip_op_indicator"}} 
		saveGroupByFormat=false 
 	     varSpecs={{name="ape", summarySubset="Mean", columnNames="MAPE", weight="Total_Demand"}
				 	{name="Total_Demand", summarySubset="Mean", columnNames="Avg_Weekly_Demand"}} 	       
 	     casOut={caslib="&_worklib.",name="_tmp_fa_mape",replace=true}; run; 
quit;

proc delete data=&outlib..output_fa_mape;
run;
data &outlib..output_fa_mape (promote=yes);
   set &_worklib.._tmp_fa_mape;
run;


/* to compare models*/
/*Delete output data if already exists */
proc delete data= &outlib..output_fa_mape_cons;
run;

proc FEDSQL sessref=mysess;
create table &outlib..output_fa_mape_cons as
 select 
	A.facility, A.service_line, A.ip_op_indicator, 
	A.MAPE AS MAPE_TSMDL, A.Avg_Weekly_Demand AS Avg_Weekly_Demand_TSMDL,
	B.MAPE AS MAPE_YOY, B.Avg_Weekly_Demand AS Avg_Weekly_Demand_YOY	

FROM &outlib..output_fa_mape_tsmdl A
LEFT OUTER JOIN &outlib..output_fa_mape_yoy B
on
A.facility = B.facility AND A.service_line=B.service_line 
AND A.ip_op_indicator =B.ip_op_indicator
;
QUIT;

proc casutil;
	promote casdata="OUTPUT_FA_MAPE_CONS" outcaslib="casuser" incaslib="casuser" drop;                   
quit;





