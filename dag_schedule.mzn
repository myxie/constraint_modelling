% Copyright (C) 2017 RW Bunney

% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.

% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.


% Implementation of DAG Scheduling problem solver in MiniZinc language
% Inspiration and code snippets from by Hakan Kjellerstrand, hakank@bonetmail.com
% http://www.hakank.org/minizinc/#scheduling_with_assignments.
% These snippets are identified in the code


include "globals.mzn";

int: num_tasks;
int: num_machines;
int: max_time;
int: final_task=num_tasks;
% set of int: TOPTASKS=0..(num_tasks-2);

set of int: TASKS=1..num_tasks;%
set of int: MACHINES=1..num_machines;

% array[1..num_tasks-2] of var int: topsort;

array[TASKS,MACHINES] of 0..max_time: comp_cost;
array[TASKS,TASKS]of 0..max_time: comm_cost;

array[TASKS] of var 0..max_time: start_time;
array[TASKS] of var 0..max_time: final_cost; % comp_cost + comm_cost for each node
array[TASKS] of var 0..max_time: end_time = [start_time[task]
												+ final_cost[task] | task in TASKS];
array[TASKS] of var 1..num_machines: allocation;

% TODO look into whether there has to be a boundary on how large a variable can be.
var 0..max_time: earliest_finish_time = max([end_time[i] | i in TASKS]);

array[MACHINES] of var 0..max_time*10: comp_bounds_array = [sum(t in TASKS)(comp_cost[t,m]) | m in MACHINES];


%annotation maybe_partial;


solve ::  seq_search([
            int_search(start_time, smallest, indomain_min,complete),
             int_search(final_cost, smallest, indomain_min, complete)])
               minimize earliest_finish_time;
predicate prec(int:task1 , int: task2, array[int] of var int: start) =
   start[task1] + final_cost[task1] <= start[task2]
   % start[task2] >= start[task1]+final_cost[task1]
;

predicate no_overlap(var int:s1, var int:d1, var int:s2, var int:d2) =
    s1 + d1 <= s2 \/ s2 + d2 <= s1
;


%    predicate has_predecessors(int:task) =
%        sum(comm_cost[..,task])>0
%    ;
%
%
%    predicate has_sucessors(int: task) =
%         sum(comm_cost[task,..]) > 0
%    ;
%
predicate edge_exists(int:task1, int:task2) =
	comm_cost[task1,task2] >0
;

%constraint exists(t in 2..num_tasks-1)(
%   start_time[t] == 0
%   )
%;

%   constraint forall(i in 1..num_tasks-2)(
%           end_time[topsort[i]] <= start_time[topsort[i+1]]
%       )
%   ;

% Ensure that there is no overlap between tasks on the same 'machine'
constraint
		forall(t1 in TASKS, t2 in TASKS where t1!=t2 /\ allocation[t1]==allocation[t2]) (
			no_overlap(start_time[t1], final_cost[t1], start_time[t2], final_cost[t2])
    )
;

% I think I can use the same approach to determining if I have a task with no predecessors (e.g. 1st task - sum of all tasks in the first column is zero) as how I detect if tasks has no successors (and thus is (one-of) the final task(s))

array [TASKS] of var int: comm_penalty = [
	if exists (s in TASKS) (comm_cost[t,s]>0 /\ sum(comm_cost[..,t])>0) then
		max (s in TASKS where comm_cost[t, s] > 0)
					(comm_cost[t, s] * (allocation[s] != allocation[t]))
	else
		0
  endif | t in TASKS];

% constraint forall (t in TASKS) (final_cost[t] >= comp_cost[t, allocation[t]]);
constraint forall (t in TASKS) (final_cost[t] = comp_cost[t, allocation[t]] + comm_penalty[t]);

constraint forall(m in MACHINES) (
      earliest_finish_time <= comp_bounds_array[m])
   ;


constraint
		forall(t1 in TASKS, t2 in TASKS where comm_cost[t1,t2]>0)(
			prec(t1, t2, start_time)
  	)
;

constraint forall (t in TASKS where t == 1 \/ t == num_tasks) (
                                 allocation[t] = 1
                                 )
                                 ;

%var int: makespan = max (t in TASKS_FINAL) (start_time[t] + final_cost[t]);

output ["allocation: \(allocation)\n"  ++ 
		"start_time:\(start_time)\n" ++ 
		"end_time: \(end_time)\n"++
		"comm_penalty:\(comm_penalty)\n"++
		"final_cost (comp_cost[i]+comm_cost[i]) :\(final_cost)\n"++
		"earliest_finish_time: \(earliest_finish_time)"] 


