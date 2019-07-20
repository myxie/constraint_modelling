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

import networkx as nx
import json
import numpy as np


def convert_json_to_dzn(jfile, dzn):
	nxgraph, machines = convert_json_to_nx(jfile)

	comp_table = format_compcost(nxgraph, machines)
	print(comp_table)
	comm_table= format_commcost(nxgraph)
	# comm_table = format_commcost(nxgraph)
	#
	# with open(dzn, 'w') as outfile:
	# 	outfile.write(str(comm_table))
	# 	outfile.write(str(comp_table))


def convert_from_nxobject(nxgraph):
	"""
	Conversion from nx.DiGraph to matrix representation.
	:param nxgraph:
	:return:
	"""
	cost_matrix = np.empty(nxgraph.size + 2, nxgraph.size + 2)
	for node in nxgraph.node:
		cost_matrix[node, node] = node

	pass


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


def format_compcost(graph, machines):
	# nodes = list(graph.nodes)
	print(graph.nodes)
	num_machines = len(machines)
	compstr = '[|{0}'.format('0, '*num_machines)
	for node in graph:
		complist = graph.node[node]['comp']
		# print(complist)
		tmp = str(complist).strip('[]')
		compstr = '{0}\n|{1},'.format(compstr, tmp)

	final_comp = '{0}\n{1}0|];'.format(compstr, '0, '*(num_machines-1))
	return final_comp


def format_commcost(graph):
	edges = list(graph.edges)
	num_nodes = len(graph)
	edge_matrix = np.zeros((num_nodes + 2, num_nodes + 2), dtype=int)
	for edge in graph.edges:
		t1, t2 = edge[0], edge[1]
		# We use t1+1 to skip the first row in our matrix,
		# which represent our 'source' node
		edge_matrix[t1+1][t2] = graph[t1][t2]['data_size']
	row_matrix = ''
	for row in edge_matrix:
		row_string = (
			str(row).strip('[]').lstrip(' ').replace('  ', ' ').replace(' ', ', '))
		row_matrix = '{0}\n|{1},'.format(row_matrix, row_string)
		# print(row_string)

	row_matrix = '[{0}|\n];'.format(row_matrix[:-1])
	print(row_matrix)
	return edges


print(convert_json_to_dzn("test/heft_nocalc.json", 'tmp.dzn'))
# def convert_from_dzn(filename):
# 	matrix = []
# 	with open(filename, 'w') as dzn:
# 		for line in dzn:
# 			matrix.append(line)
# 	pass
