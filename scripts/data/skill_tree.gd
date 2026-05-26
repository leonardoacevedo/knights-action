extends Resource
class_name SkillTree

## Container de todos los nodos del árbol de habilidades. GDD §6.2.
##
## Una única instancia: resources/skills/main_tree.tres
## Se carga en PlayerProgression._ready(). Stateless — solo datos.

@export var nodes: Array[SkillNode] = []


## Retorna el nodo con el id dado, o null si no existe.
func get_node_by_id(id: StringName) -> SkillNode:
	for node: SkillNode in nodes:
		if node.id == id:
			return node
	return null


## Todos los nodos de una rama específica.
func get_nodes_by_branch(branch: SkillNode.Branch) -> Array[SkillNode]:
	var result: Array[SkillNode] = []
	for node: SkillNode in nodes:
		if node.branch == branch:
			result.append(node)
	return result


## Nodos raíz: sin prerequisites. Son los desbloqueable de entrada con 1 punto.
func get_root_nodes() -> Array[SkillNode]:
	var result: Array[SkillNode] = []
	for node: SkillNode in nodes:
		if node.prerequisites.is_empty():
			result.append(node)
	return result


## Nodos inmediatos que este nodo desbloquea (hijos directos en el árbol).
func get_children_of(parent_id: StringName) -> Array[SkillNode]:
	var result: Array[SkillNode] = []
	for node: SkillNode in nodes:
		if parent_id in node.prerequisites:
			result.append(node)
	return result
