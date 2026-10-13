/* Copyright (C) 2026 the Sidescroller Recomps contributors.
 * Licensed under the GNU General Public License v2 or later. See LICENSE.md.
 *
 * Makes the sound chip emulation in opl2.c available to Godot as a class:
 *
 *     var chip: Object = ClassDB.instantiate("D2Opl")
 *     chip.write(0x20, 0x01)       # set a register
 *     var s: int = chip.sample()   # the next sample, -32768..32767, at 49716 Hz
 *     chip.reset()
 *     chip.free()                  # it is a plain Object, not reference counted
 *
 * Written against Godot's C interface for extensions, with no other library.
 * The header gdextension_interface.h is not kept in this repository; the
 * build script asks the user's own Godot to write it out
 * (tools/build_native.py).
 */
#include "gdextension_interface.h"
#include "blit.h"
#include "opl2.h"

#include <stddef.h>

#if defined(_WIN32)
#define D2_EXPORT __declspec(dllexport)
#else
#define D2_EXPORT __attribute__((visibility("default")))
#endif

/* Godot's StringName and String are each one pointer wide. */
typedef struct {
	void *opaque;
} D2StringName;
typedef struct {
	void *opaque;
} D2String;

#define PROPERTY_USAGE_DEFAULT 6

static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceStringNameNewWithLatin1Chars string_name_new;
static GDExtensionInterfaceStringNewWithLatin1Chars string_new;
static GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceClassdbConstructObject3 construct_object;
static GDExtensionInterfaceObjectSetInstance object_set_instance;
static GDExtensionInterfaceMemAlloc mem_alloc;
static GDExtensionInterfaceMemFree mem_free;
static GDExtensionVariantFromTypeConstructorFunc variant_from_int;
static GDExtensionTypeFromVariantConstructorFunc int_from_variant;
static GDExtensionTypeFromVariantConstructorFunc pba_from_variant;
static GDExtensionVariantFromTypeConstructorFunc variant_from_pba;
static GDExtensionInterfacePackedByteArrayOperatorIndex pba_index;
static GDExtensionInterfacePackedByteArrayOperatorIndexConst pba_index_const;
static GDExtensionPtrBuiltInMethod pba_size;
static GDExtensionPtrBuiltInMethod pba_resize;
static GDExtensionPtrConstructor pba_new;
static GDExtensionPtrDestructor pba_free;

static D2StringName name_class;
static D2StringName name_parent;
static D2StringName name_empty;
static D2StringName name_blit;
static D2String string_empty;

/* --- the class -------------------------------------------------------- */

static GDExtensionObjectPtr create_instance(void *class_userdata, GDExtensionBool notify_postinitialize) {
	(void)class_userdata;
	(void)notify_postinitialize;
	GDExtensionObjectPtr object = construct_object(&name_parent);
	Opl2Chip *chip = (Opl2Chip *)mem_alloc(sizeof(Opl2Chip));
	opl2_reset(chip);
	object_set_instance(object, &name_class, chip);
	return object;
}

static void free_instance(void *class_userdata, GDExtensionClassInstancePtr instance) {
	(void)class_userdata;
	if (instance != NULL) {
		mem_free(instance);
	}
}

/* --- write(reg, value) ------------------------------------------------ */

static void write_ptrcall(void *userdata, GDExtensionClassInstancePtr instance, const GDExtensionConstTypePtr *args,
		GDExtensionTypePtr ret) {
	(void)userdata;
	(void)ret;
	opl2_write((Opl2Chip *)instance, (uint8_t)(*(const int64_t *)args[0]), (uint8_t)(*(const int64_t *)args[1]));
}

static void write_call(void *userdata, GDExtensionClassInstancePtr instance, const GDExtensionConstVariantPtr *args,
		GDExtensionInt argument_count, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
	(void)userdata;
	(void)ret;
	if (argument_count < 2) {
		error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
		error->expected = 2;
		return;
	}
	int64_t reg = 0;
	int64_t value = 0;
	int_from_variant(&reg, (GDExtensionVariantPtr)args[0]);
	int_from_variant(&value, (GDExtensionVariantPtr)args[1]);
	opl2_write((Opl2Chip *)instance, (uint8_t)reg, (uint8_t)value);
	error->error = GDEXTENSION_CALL_OK;
}

/* --- sample() ---------------------------------------------------------- */

static void sample_ptrcall(void *userdata, GDExtensionClassInstancePtr instance, const GDExtensionConstTypePtr *args,
		GDExtensionTypePtr ret) {
	(void)userdata;
	(void)args;
	*(int64_t *)ret = opl2_sample((Opl2Chip *)instance);
}

static void sample_call(void *userdata, GDExtensionClassInstancePtr instance, const GDExtensionConstVariantPtr *args,
		GDExtensionInt argument_count, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
	(void)userdata;
	(void)args;
	(void)argument_count;
	int64_t value = opl2_sample((Opl2Chip *)instance);
	variant_from_int(ret, &value);
	error->error = GDEXTENSION_CALL_OK;
}

/* --- reset() ----------------------------------------------------------- */

static void reset_ptrcall(void *userdata, GDExtensionClassInstancePtr instance, const GDExtensionConstTypePtr *args,
		GDExtensionTypePtr ret) {
	(void)userdata;
	(void)args;
	(void)ret;
	opl2_reset((Opl2Chip *)instance);
}

static void reset_call(void *userdata, GDExtensionClassInstancePtr instance, const GDExtensionConstVariantPtr *args,
		GDExtensionInt argument_count, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
	(void)userdata;
	(void)args;
	(void)argument_count;
	(void)ret;
	opl2_reset((Opl2Chip *)instance);
	error->error = GDEXTENSION_CALL_OK;
}

/* --- D2Blit: planes(src, src_off, pitch, rows) -------------------------- */

static GDExtensionObjectPtr blit_create_instance(void *class_userdata, GDExtensionBool notify_postinitialize) {
	(void)class_userdata;
	(void)notify_postinitialize;
	GDExtensionObjectPtr object = construct_object(&name_parent);
	/* No instance data: the method is stateless, but the object must be bound
	 * to the class or it would not have the method. */
	object_set_instance(object, &name_blit, NULL);
	return object;
}

static void blit_free_instance(void *class_userdata, GDExtensionClassInstancePtr instance) {
	(void)class_userdata;
	(void)instance;
}

/* The conversion behind planes(): fills `out` (an empty PackedByteArray) or leaves it empty when the
 * request is outside `src` or makes no sense (the caller then uses its own loop). */
static void planes_into(GDExtensionConstTypePtr src, int64_t src_off, int64_t pitch, int64_t rows, GDExtensionTypePtr out) {
	if (rows <= 0 || src_off < 0 || pitch < D2_BLIT_WIDTH) {
		return;
	}
	int64_t size = 0;
	pba_size((GDExtensionTypePtr)src, NULL, &size, 0);
	if (src_off + (rows - 1) * pitch + D2_BLIT_WIDTH > size) {
		return;
	}
	int64_t total = 4 * rows * D2_BLIT_ROW_BYTES;
	const GDExtensionConstTypePtr resize_args[1] = { &total };
	int64_t resized = 0;    /* resize() returns an Error: it needs somewhere to put it */
	pba_resize(out, resize_args, &resized, 1);
	d2_blit_planes(pba_index_const(src, 0), src_off, pitch, rows, pba_index(out, 0));
}

static void planes_ptrcall(void *userdata, GDExtensionClassInstancePtr instance, const GDExtensionConstTypePtr *args,
		GDExtensionTypePtr ret) {
	(void)userdata;
	(void)instance;
	planes_into(args[0], *(const int64_t *)args[1], *(const int64_t *)args[2], *(const int64_t *)args[3], ret);
}

/* A PackedByteArray is an opaque 16 bytes to an extension (Godot's extension_api.json, builtin_class_sizes):
 * the Variant version needs real storage for one, constructed and destroyed here. */
typedef struct {
	_Alignas(8) uint8_t opaque[16];
} D2Bytes;

static void planes_call(void *userdata, GDExtensionClassInstancePtr instance, const GDExtensionConstVariantPtr *args,
		GDExtensionInt argument_count, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
	(void)userdata;
	(void)instance;
	if (argument_count < 4) {
		error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
		error->expected = 4;
		return;
	}
	D2Bytes src;
	D2Bytes out;
	pba_new(&out, NULL);
	pba_from_variant(&src, (GDExtensionVariantPtr)args[0]);
	int64_t src_off = 0;
	int64_t pitch = 0;
	int64_t rows = 0;
	int_from_variant(&src_off, (GDExtensionVariantPtr)args[1]);
	int_from_variant(&pitch, (GDExtensionVariantPtr)args[2]);
	int_from_variant(&rows, (GDExtensionVariantPtr)args[3]);
	planes_into(&src, src_off, pitch, rows, &out);
	variant_from_pba(ret, &out);
	pba_free(&src);
	pba_free(&out);
	error->error = GDEXTENSION_CALL_OK;
}

/* --- registration ------------------------------------------------------ */

static GDExtensionPropertyInfo int_property(D2StringName *name) {
	GDExtensionPropertyInfo info;
	info.type = GDEXTENSION_VARIANT_TYPE_INT;
	info.name = name;
	info.class_name = &name_empty;
	info.hint = 0;
	info.hint_string = &string_empty;
	info.usage = PROPERTY_USAGE_DEFAULT;
	return info;
}

static void bind(const char *method, GDExtensionClassMethodCall call, GDExtensionClassMethodPtrCall ptrcall,
		int argument_count, const char *first, const char *second, int returns_int) {
	D2StringName name_method;
	D2StringName name_first;
	D2StringName name_second;
	string_name_new(&name_method, method, 1);
	string_name_new(&name_first, first, 1);
	string_name_new(&name_second, second, 1);

	GDExtensionPropertyInfo arguments[2];
	arguments[0] = int_property(&name_first);
	arguments[1] = int_property(&name_second);
	GDExtensionClassMethodArgumentMetadata metadata[2] = { GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
		GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE };
	GDExtensionPropertyInfo return_info = int_property(&name_empty);

	GDExtensionClassMethodInfo info;
	info.name = &name_method;
	info.method_userdata = NULL;
	info.call_func = call;
	info.ptrcall_func = ptrcall;
	info.method_flags = GDEXTENSION_METHOD_FLAGS_DEFAULT;
	info.has_return_value = returns_int ? 1 : 0;
	info.return_value_info = returns_int ? &return_info : NULL;
	info.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
	info.argument_count = (uint32_t)argument_count;
	info.arguments_info = arguments;
	info.arguments_metadata = metadata;
	info.default_argument_count = 0;
	info.default_arguments = NULL;
	register_method(library, &name_class, &info);
}

static GDExtensionPropertyInfo pba_property(D2StringName *name) {
	GDExtensionPropertyInfo info;
	info.type = GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY;
	info.name = name;
	info.class_name = &name_empty;
	info.hint = 0;
	info.hint_string = &string_empty;
	info.usage = PROPERTY_USAGE_DEFAULT;
	return info;
}

/* D2Blit's one method: a PackedByteArray and three ints in, a PackedByteArray out. */
static void bind_blit(const char *method, GDExtensionClassMethodCall call, GDExtensionClassMethodPtrCall ptrcall,
		const char *a0, const char *a1, const char *a2, const char *a3) {
	D2StringName name_method;
	D2StringName name_a0;
	D2StringName name_a1;
	D2StringName name_a2;
	D2StringName name_a3;
	string_name_new(&name_method, method, 1);
	string_name_new(&name_a0, a0, 1);
	string_name_new(&name_a1, a1, 1);
	string_name_new(&name_a2, a2, 1);
	string_name_new(&name_a3, a3, 1);

	GDExtensionPropertyInfo arguments[4];
	arguments[0] = pba_property(&name_a0);
	arguments[1] = int_property(&name_a1);
	arguments[2] = int_property(&name_a2);
	arguments[3] = int_property(&name_a3);
	GDExtensionClassMethodArgumentMetadata metadata[4] = { GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
		GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE, GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
		GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE };
	GDExtensionPropertyInfo return_info = pba_property(&name_empty);

	GDExtensionClassMethodInfo info;
	info.name = &name_method;
	info.method_userdata = NULL;
	info.call_func = call;
	info.ptrcall_func = ptrcall;
	info.method_flags = GDEXTENSION_METHOD_FLAGS_DEFAULT;
	info.has_return_value = 1;
	info.return_value_info = &return_info;
	info.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
	info.argument_count = 4;
	info.arguments_info = arguments;
	info.arguments_metadata = metadata;
	info.default_argument_count = 0;
	info.default_arguments = NULL;
	register_method(library, &name_blit, &info);
}

static void initialize(void *userdata, GDExtensionInitializationLevel level) {
	(void)userdata;
	if (level != GDEXTENSION_INITIALIZATION_SCENE) {
		return;
	}
	string_name_new(&name_class, "D2Opl", 1);
	string_name_new(&name_parent, "Object", 1);
	string_name_new(&name_empty, "", 1);
	string_name_new(&name_blit, "D2Blit", 1);
	string_new(&string_empty, "");

	GDExtensionClassCreationInfo6 info;
	info.is_virtual = 0;
	info.is_abstract = 0;
	info.is_exposed = 1;
	info.is_runtime = 0;
	info.icon_path = NULL;
	info.set_func = NULL;
	info.get_func = NULL;
	info.get_property_list_func = NULL;
	info.free_property_list_func = NULL;
	info.property_can_revert_func = NULL;
	info.property_get_revert_func = NULL;
	info.validate_property_func = NULL;
	info.notification_func = NULL;
	info.to_string_func = NULL;
	info.reference_func = NULL;
	info.unreference_func = NULL;
	info.create_instance_func = create_instance;
	info.free_instance_func = free_instance;
	info.recreate_instance_func = NULL;
	info.get_virtual_func = NULL;
	info.get_virtual_call_data_func = NULL;
	info.call_virtual_with_data_func = NULL;
	info.class_userdata = NULL;
	register_class(library, &name_class, &name_parent, &info);

	bind("write", write_call, write_ptrcall, 2, "reg", "value", 0);
	bind("sample", sample_call, sample_ptrcall, 0, "", "", 1);
	bind("reset", reset_call, reset_ptrcall, 0, "", "", 0);

	GDExtensionClassCreationInfo6 blit_info;
	blit_info.is_virtual = 0;
	blit_info.is_abstract = 0;
	blit_info.is_exposed = 1;
	blit_info.is_runtime = 0;
	blit_info.icon_path = NULL;
	blit_info.set_func = NULL;
	blit_info.get_func = NULL;
	blit_info.get_property_list_func = NULL;
	blit_info.free_property_list_func = NULL;
	blit_info.property_can_revert_func = NULL;
	blit_info.property_get_revert_func = NULL;
	blit_info.validate_property_func = NULL;
	blit_info.notification_func = NULL;
	blit_info.to_string_func = NULL;
	blit_info.reference_func = NULL;
	blit_info.unreference_func = NULL;
	blit_info.create_instance_func = blit_create_instance;
	blit_info.free_instance_func = blit_free_instance;
	blit_info.recreate_instance_func = NULL;
	blit_info.get_virtual_func = NULL;
	blit_info.get_virtual_call_data_func = NULL;
	blit_info.call_virtual_with_data_func = NULL;
	blit_info.class_userdata = NULL;
	register_class(library, &name_blit, &name_parent, &blit_info);

	bind_blit("planes", planes_call, planes_ptrcall, "src", "src_off", "pitch", "rows");
}

static void deinitialize(void *userdata, GDExtensionInitializationLevel level) {
	(void)userdata;
	(void)level;
}

D2_EXPORT GDExtensionBool d2opl_init(GDExtensionInterfaceGetProcAddress get_proc, GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	library = p_library;
	string_name_new = (GDExtensionInterfaceStringNameNewWithLatin1Chars)get_proc("string_name_new_with_latin1_chars");
	string_new = (GDExtensionInterfaceStringNewWithLatin1Chars)get_proc("string_new_with_latin1_chars");
	register_class = (GDExtensionInterfaceClassdbRegisterExtensionClass6)get_proc("classdb_register_extension_class6");
	register_method =
			(GDExtensionInterfaceClassdbRegisterExtensionClassMethod)get_proc("classdb_register_extension_class_method");
	construct_object = (GDExtensionInterfaceClassdbConstructObject3)get_proc("classdb_construct_object3");
	object_set_instance = (GDExtensionInterfaceObjectSetInstance)get_proc("object_set_instance");
	mem_alloc = (GDExtensionInterfaceMemAlloc)get_proc("mem_alloc");
	mem_free = (GDExtensionInterfaceMemFree)get_proc("mem_free");
	GDExtensionInterfaceGetVariantFromTypeConstructor get_from =
			(GDExtensionInterfaceGetVariantFromTypeConstructor)get_proc("get_variant_from_type_constructor");
	GDExtensionInterfaceGetVariantToTypeConstructor get_to =
			(GDExtensionInterfaceGetVariantToTypeConstructor)get_proc("get_variant_to_type_constructor");

	/* An older Godot lacks some of these; the game then runs without this
	 * library, and so without AdLib sound, and says so. */
	if (!string_name_new || !string_new || !register_class || !register_method || !construct_object
			|| !object_set_instance || !mem_alloc || !mem_free || !get_from || !get_to) {
		return 0;
	}
	variant_from_int = get_from(GDEXTENSION_VARIANT_TYPE_INT);
	int_from_variant = get_to(GDEXTENSION_VARIANT_TYPE_INT);
	variant_from_pba = get_from(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);
	pba_from_variant = get_to(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);
	pba_index = (GDExtensionInterfacePackedByteArrayOperatorIndex)get_proc("packed_byte_array_operator_index");
	pba_index_const = (GDExtensionInterfacePackedByteArrayOperatorIndexConst)get_proc("packed_byte_array_operator_index_const");
	GDExtensionInterfaceVariantGetPtrBuiltinMethod get_builtin =
			(GDExtensionInterfaceVariantGetPtrBuiltinMethod)get_proc("variant_get_ptr_builtin_method");
	GDExtensionInterfaceVariantGetPtrConstructor get_ctor =
			(GDExtensionInterfaceVariantGetPtrConstructor)get_proc("variant_get_ptr_constructor");
	GDExtensionInterfaceVariantGetPtrDestructor get_dtor =
			(GDExtensionInterfaceVariantGetPtrDestructor)get_proc("variant_get_ptr_destructor");
	if (get_ctor != NULL && get_dtor != NULL) {
		pba_new = get_ctor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY, 0);
		pba_free = get_dtor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);
	}
	if (get_builtin != NULL) {
		D2StringName name_size;
		D2StringName name_resize;
		string_name_new(&name_size, "size", 1);
		string_name_new(&name_resize, "resize", 1);
		pba_size = get_builtin(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY, &name_size, 3173160232);
		pba_resize = get_builtin(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY, &name_resize, 848867239);
	}
	if (variant_from_pba == NULL || pba_from_variant == NULL || pba_index == NULL || pba_index_const == NULL
			|| pba_size == NULL || pba_resize == NULL || pba_new == NULL || pba_free == NULL) {
		return 0;
	}

	r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
	r_initialization->userdata = NULL;
	r_initialization->initialize = initialize;
	r_initialization->deinitialize = deinitialize;
	return 1;
}
