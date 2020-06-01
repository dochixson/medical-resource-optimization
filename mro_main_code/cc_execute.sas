*------------------------------------------------------------------------------*
| Program: cc_execute
*------------------------------------------------------------------------------*;

%macro cc_execute(
         inlib=cc
         ,outlib=casuser
         ,opt_param_lib=cc
         ,_worklib=casuser
         ,input_utilization=input_utilization
         ,input_capacity=input_capacity
         ,input_financials=input_financials
         ,input_service_attributes=input_service_attributes
         ,input_demand=input_demand
         ,input_demand_forecast=input_demand_forecast
         ,input_opt_parameters=input_opt_parameters
         ,output_opt_detail=output_opt_detail
         ,output_opt_detail_agg=output_opt_detail_agg
         ,output_opt_summary=output_opt_summary
         ,output_opt_resource_usage=output_opt_resource_usage
         ,output_opt_resource_usage_detail=output_opt_resource_usage_detail
         ,output_opt_covid_test_usage=output_opt_covid_test_usage
         ,run_dp=1
         ,run_fcst=1
         ,run_opt=1
         ,_debug=0
         );


   %if %sysevalf(&run_dp.=1) %then %do;

      %cc_data_prep(
         inlib=&inlib.
         ,outlib=&outlib.
         ,opt_param_lib=&opt_param_lib.
         ,input_utilization=&input_utilization.
         ,input_capacity=&input_capacity.
         ,input_financials=&input_financials.
         ,input_service_attributes=&input_service_attributes.
         ,input_demand=&input_demand.
         ,input_demand_forecast=&input_demand_forecast
         ,input_opt_parameters=&input_opt_parameters.
         ,exclude_str=%str(facility in ('Florida','CCCHR') or service_line='Evaluation and Management')
         ,_worklib=&_worklib.
         ,_debug=&_debug.
         );

   %end;

   %if %sysevalf(&run_fcst.=1) %then %do;

      %cc_forecast_demand(
         inlib=&inlib.
         ,outlib=&outlib.
         ,input_demand=input_demand_pp
         ,output_fd_demand_fcst=output_fd_demand_fcst
         ,_worklib=&_worklib.
         ,_debug=&_debug.
         );

   %end;

   %if %sysevalf(&run_opt.=1) %then %do;

      %cc_optimize(
         inlib=&inlib.
         ,outlib=&outlib.
         ,input_demand_fcst=output_fd_demand_fcst
         ,output_opt_detail=&output_opt_detail.
         ,output_opt_detail_agg=&output_opt_detail_agg.
         ,output_opt_summary=&output_opt_summary.
         ,output_opt_resource_usage=&output_opt_resource_usage.
         ,output_opt_resource_usage_detail=&output_opt_resource_usage_detail.
         ,output_opt_covid_test_usage=&output_opt_covid_test_usage.
         ,_worklib=&_worklib.
         ,_debug=&_debug
         );

   %end;

%mend cc_execute;