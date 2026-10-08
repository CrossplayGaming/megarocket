# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name AndroidSaf
extends RefCounted
## A folder the player picked with Android's system picker (AND-02): the
## picker gives a document-tree URI (content://...), which Godot's file
## access cannot open, so the tree is listed and its files copied through
## Android's own DocumentsContract and ContentResolver, called with
## JavaClassWrapper (Android 10 and later, as the picker itself). Nothing is
## written to the picked folder.

const DIR_MIME: String = "vnd.android.document/directory"

var error: String = ""
var _resolver: Object = null
var _docs: Object = null
var _uri: Object = null


## Whether this can work here (an Android build with the runtime plugin).
static func available() -> bool:
	return OS.has_feature("android") and Engine.has_singleton("AndroidRuntime")


func _init() -> void:
	if not available():
		error = "not an Android build"
		return
	var activity: Object = Engine.get_singleton("AndroidRuntime").getActivity()
	_resolver = activity.getContentResolver()
	_docs = JavaClassWrapper.wrap("android.provider.DocumentsContract")
	_uri = JavaClassWrapper.wrap("android.net.Uri")


func _check(what: String) -> bool:
	var e: Object = JavaClassWrapper.get_exception()
	if e != null:
		error = "%s: %s" % [what, e.toString()]
		return false
	return true


## The documents in the picked tree, `depth` levels down: [{path (relative,
## "/"-separated), name, size, dir, doc}] ("doc" is the document's id).
func list_tree(tree_uri: String, depth: int = 2) -> Array:
	var tree: Object = _uri.parse(tree_uri)
	var root_id: String = _docs.getTreeDocumentId(tree)
	if not _check("reading the folder's id"):
		return []
	var out: Array = []
	_list(tree, root_id, "", depth, out)
	return out


func _list(tree: Object, doc_id: String, prefix: String, depth: int, out: Array) -> void:
	var children: Object = _docs.buildChildDocumentsUriUsingTree(tree, doc_id)
	var cols: PackedStringArray = ["document_id", "_display_name", "mime_type", "_size"]
	var cursor: Object = _resolver.query(children, cols, "", PackedStringArray(), "", null)
	if not _check("listing " + (prefix if prefix != "" else "the folder")) or cursor == null:
		return
	var subdirs: Array = []
	while cursor.moveToNext():
		var id: String = cursor.getString(0)
		var name: String = cursor.getString(1)
		var is_dir: bool = cursor.getString(2) == DIR_MIME
		var entry: Dictionary = {"path": prefix + name, "name": name, "size": int(cursor.getLong(3)), "dir": is_dir, "doc": id}
		out.append(entry)
		if is_dir:
			subdirs.append(entry)
	cursor.close()
	if depth > 0:
		for d: Dictionary in subdirs:
			_list(tree, d.doc, d.path + "/", depth - 1, out)


## Copies one document of the tree to `dest` (an absolute path in app storage).
func copy(tree_uri: String, doc_id: String, dest: String) -> bool:
	var tree: Object = _uri.parse(tree_uri)
	var doc: Object = _docs.buildDocumentUriUsingTree(tree, doc_id)
	var input: Object = _resolver.openInputStream(doc)
	if not _check("opening " + doc_id) or input == null:
		return false
	var output: Object = JavaClassWrapper.wrap("java.io.FileOutputStream").FileOutputStream(dest)
	if not _check("creating " + dest) or output == null:
		input.close()
		return false
	JavaClassWrapper.wrap("android.os.FileUtils").copy(input, output)
	var ok: bool = _check("copying " + doc_id)
	input.close()
	output.close()
	return ok
