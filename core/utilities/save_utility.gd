class_name SaveUtility
extends GxUtility
## Utility 层：把 gd-common 的 SaveSystem autoload 包一层。
##
## 为什么不让 Model 直接调 SaveSystem：autoload 属于基础设施，按分层规则
## 只有 Utility 层能碰。多一层封装的好处是，以后换成云存档或换序列化格式，
## 只改这个文件，Model 和 System 一行都不用动。

const SLOT_COUNT := 3


func _on_init() -> void:
	SaveSystem.set_version(1)
	SaveSystem.set_migrator(_migrate)


## 写入一个槽位。返回是否成功。
func save(slot: int, data: Dictionary) -> bool:
	return SaveSystem.save_to_slot(slot, data)


## 读取一个槽位。槽位不存在或损坏时返回空字典。
func load_slot(slot: int) -> Dictionary:
	return SaveSystem.load_from_slot(slot)


func has_slot(slot: int) -> bool:
	return SaveSystem.has_slot(slot)


func delete_slot(slot: int) -> bool:
	return SaveSystem.delete_slot(slot)


## 已占用的槽位编号，已排序。
func used_slots() -> Array[int]:
	return SaveSystem.list_slots()


## 存档版本迁移。加字段时在这里补默认值，不要指望旧存档里有它。
func _migrate(data: Dictionary, from_version: int, to_version: int) -> Dictionary:
	print("[SaveUtility] migrating save data v%d -> v%d" % [from_version, to_version])
	return data
