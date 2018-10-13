% Implementation of DAG Scheduling problem solver in MiniZinc language
% Inspiration and code snippets from by Hakan Kjellerstrand, hakank@bonetmail.com 
% http://www.hakank.org/minizinc/#scheduling_with_assignments. 
% These snippets are identified in the code 


include "globals.mzn";

int: num_tasks; 
int: num_machines; 
int: max_time;
int: final_task=num_tasks;

set of int: TASKS=1..num_tasks;
set of int: TASKS_NOFINAL=1..num_tasks-1; % Final task logic is different
set of int: MACHINES=1..num_machines;


array[TASKS,MACHINES] of 0..max_time: comp_cost;
array[TASKS,TASKS]of 0..max_time: comm_cost;

array[TASKS] of var 0..max_time: start_time; 
array[TASKS] of var 0..max_time: final_cost; % comp_cost + comm_cost for each node 
array[TASKS] of var 0..max_time: end_time = [start_time[task]  	
												+ final_cost[task] | task in TASKS];
array[TASKS] of var 0..num_machines: allocation;

var 0..max_time: earliest_finish_time = max([end_time[i] | i in TASKS]);

%solve satisfy;
solve minimize earliest_finish_time;
%solve :: int_search(end_time ++ allocation , input_order, indomain, complete) minimize earliest_finish_time;% http://www.hakank.org/minizinc/#scheduling_with_assignments. 
% This ensures that job1 must start before job2

%function calc_final_cost() =
%	if(allocation[t1]==allocation[t2])(
%		final_cost=)
%;

predicate prec(int:task1 , int: task2, array[int] of var int: start) =
   start[task1] + final_cost[task1] <= start[task2]
;

predicate no_overlap(var int:s1, var int:d1, var int:s2, var int:d2) =
    s1 + d1 <= s2 \/ s2 + d2 <= s1 
;

% Ensure that there is no overlap between tasks on the same 'machine'
constraint
		forall(t1 in TASKS, t2 in TASKS where t1!=t2 /\ allocation[t1]==allocation[t2]) (
			no_overlap(start_time[t1], final_cost[t1], start_time[t2], final_cost[t2])
    )
;

% If task 1 and task 2 are allocation 
constraint
	forall(t1 in TASKS,t2 in TASKS where allocation[t1]==allocation[t2]  /\ comm_cost[t1,t2]>0)(
		final_cost[t1]=comp_cost[t1,allocation[t1]]
	)
;

constraint
	forall(t1 in TASKS,t2 in TASKS where allocation[t1]!=allocation[t2] /\ comm_cost[t1,t2]>0)(
		final_cost[t1]=comp_cost[t1,allocation[t1]] + comm_cost[t1,t2]
	)
;

constraint
	exists(m in MACHINES where allocation[num_tasks] == m )(
		% Final task is assigned to allocation
			final_cost[num_tasks]=comp_cost[num_tasks,m]
	)
;

% assign the final task such that the cost is minimized
%constraint

constraint 
	forall(t1 in TASKS_NOFINAL where comm_cost[t1,final_task]>0)(
		exists(m in MACHINES)(
		allocation[final_task] = m
		/\
		prec(t1,final_task,start_time)
		/\
    	no_overlap (start_time[t1],final_cost[t1],
			start_time[final_task],final_cost[final_task])
    	)
     )
;

constraint
		forall(t1 in TASKS, t2 in TASKS where comm_cost[t1,t2]>0)(
			prec(t1, t2, start_time)
  	)
;



output ["allocation: \(allocation)\n"  ++ 
		"start_time:\(start_time)\n" ++ 
		"end_time: \(end_time)\n"++
		"final_cost (comp_cost[i]+comm_cost[i]) :\(final_cost)\n"++
		"earliest_finish_time: \(earliest_finish_time)"] 


