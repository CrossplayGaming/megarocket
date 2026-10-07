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

static D2StringName name_class;
static D2StringName name_parent;
static D2StringName name_empty;
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

static void initialize(void *userdata, GDExtensionInitializationLevel level) {
	(void)userdata;
	if (level != GDEXTENSION_INITIALIZATION_SCENE) {
		return;
	}
	string_name_new(&name_class, "D2Opl", 1);
	string_name_new(&name_parent, "Object", 1);
	string_name_new(&name_empty, "", 1);
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

	r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
	r_initialization->userdata = NULL;
	r_initialization->initialize = initialize;
	r_initialization->deinitialize = deinitialize;
	return 1;
}
