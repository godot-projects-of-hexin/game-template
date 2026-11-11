class_name SaveUtility
extends GxUtility
## Utility 层：把 SaveSystem autoload 包一层，只有 Utility 能碰基础设施。
## 换云存档或换序列化格式时只改这个文件。

## autoload 全局名在 --script 模式下不存在，硬引用会让整个脚本编译失败，
## 所以运行时按节点路径查找并判空。
func _saves() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(^"SaveSystem")
	return null


func _on_init() -> void:
	var saves := _saves()
	if saves == null:
		return
	saves.set_version(1)
	saves.set_migrator(_migrate)


## 写入一个槽位。返回是否成功。
func save(slot: int, data: Dictionary) -> bool:
	var saves := _saves()
	return saves != null and saves.save_to_slot(slot, data)


## 读取一个槽位。槽位不存在或损坏时返回空字典。
func load_slot(slot: int) -> Dictionary:
	var saves := _saves()
	return {} if saves == null else saves.load_from_slot(slot)


func has_slot(slot: int) -> bool:
	var saves := _saves()
	return saves != null and saves.has_slot(slot)


func delete_slot(slot: int) -> bool:
	var saves := _saves()
	return saves != null and saves.delete_slot(slot)


## 已占用的槽位编号，已排序。
func used_slots() -> Array[int]:
	var saves := _saves()
	return [] if saves == null else saves.list_slots()


## 存档版本迁移。加字段时在这里补默认值，不要指望旧存档里有它。
func _migrate(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:
	return data
