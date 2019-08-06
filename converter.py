# Copyright (C) 2019 RW Bunney

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


"""
Module to convert from a graphml DAG to the format required for our MiniZinc model


A ".dzn" file will have the format:

	num_tasks = # e.g. 5
	num_machines = # e.g. 3

	comp_cost = [ # assume '3' machines
				|0,0,0, # Must pad with zeros at beginning and end for 'source' and 'sink'
				|,,,
				|,,,|]

	comm_cost = [# pad each row with 0 at the beginning and end \
				|0,0,0,0,0,0,0,
									(these represent the 'source' and sink nodes')

"""
import os

import networkx as nx
import json
import sys
import numpy as np


def convert_json_to_dzn(jfile, dzn, max_time):
	nxgraph, machines = convert_json_to_nx(jfile)
	num_tasks = nx.number_of_nodes(nxgraph)
	num_machines = len(machines)
	comp_table = format_compcost(nxgraph, num_machines)
	comm_table = format_commcost(nxgraph)

	with open(dzn, 'w') as dfile:
		format_dznfile(dfile, num_tasks, num_machines, comm_table, comp_table, max_time)


def format_dznfile(dfile, num_tasks, num_machines, comm_table, comp_table, max_time):
	"""

	:param dfile: The name of the .dzn file to be generated
	:param num_tasks: The number of tasks for the given problem
	:param num_machines: The number of machines provided for the given problem
	:param comm_table: The computation cost matrix
	:param comp_table: The communication cost matrix
	:param max_time: The maximum length the schedule can be to be considered valid.
	:return:
	"""
	dfile.write('num_tasks={0};\n'.format(num_tasks+2))  # +2 for source/sink node
	dfile.write('num_machines={0};\n'.format(num_machines))
	dfile.write('comp_cost={0};\n'.format(comp_table))
	dfile.write('comm_cost={0};\n'.format(comm_table))
	dfile.write('max_time={0};\n'.format(max_time))


def convert_json_to_nx(jfile):
	"""
	Converts from json to Networkx graph object
	:param jfile:
	:return:
	"""
	with open(jfile) as graph_data:
		tmp = json.load(graph_data)
		graph = nx.readwrite.json_graph.node_link_graph(tmp['graph'])
		machines = tmp['system']['resource']

	return graph, machines


def format_compcost(graph, num_machines):
	# nodes = list(graph.nodes)
	compstr = '[|{0}'.format('0, ' * num_machines)
	for node in graph:
		complist = graph.node[node]['comp']
		# print(complist)
		tmp = str(complist).strip('[]')
		compstr = '{0}\n|{1},'.format(compstr, tmp)

	final_comp = '{0}\n|{1}0|]'.format(compstr, '0, ' * (num_machines - 1))
	return final_comp


def format_commcost(graph):
	num_nodes = len(graph)
	edge_matrix = np.zeros((num_nodes + 2, num_nodes + 2), dtype=int)
	for edge in graph.edges:
		t1, t2 = edge[0], edge[1]
		# We use t1+1 to skip the first row in our matrix,
		# which represent our 'source' node
		edge_matrix[t1 + 1][t2+1] = graph[t1][t2]['data_size']
	print(edge_matrix)
	row_matrix = '['
	for row in edge_matrix:
		row_string = (
			str(row).strip('[]').lstrip(' ').replace('  ', ',').replace(', ', ',').replace(' ', ','))
		# print(row_string[1:])
		row_matrix = '{0}|{1},\n'.format(row_matrix, row_string)
		# print(row_string)

	row_matrix = '{0}|]'.format(row_matrix[:-2])
	return row_matrix


if __name__ == '__main__':
	args = sys.argv
	# argv[1] is the directory we want to search for json files
	print(args)
	if os.path.isdir(args[1]):
		print(args[1])
		for path in os.listdir(args[1]):
			if 'json' in path:
				convert_json_to_dzn('{0}/{1}'.format(args[1], path), 'exp/dzn/{0}.dzn'.format(path[:-5]), 5000)

