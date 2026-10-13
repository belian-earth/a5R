use std::ffi::{c_char, c_void, CStr};
use std::ptr;

use extendr_api::prelude::*;

use crate::cell_raw::{raw8_planes_to_list, CellSlices};
use crate::covering::read_coverings;

// --- Arrow C data interface ---
//
// Cells cross into Arrow through the C data interface
// (https://arrow.apache.org/docs/format/CDataInterface.html), so a column
// moves as one contiguous uint64 buffer instead of one R object per cell.
// The arrow R package imports and exports these structs by address, given
// as a decimal string; a `FfiSlot` external pointer owns each pair and
// releases whatever Arrow has not taken.

#[repr(C)]
struct ArrowSchema {
    format: *const c_char,
    name: *const c_char,
    metadata: *const c_char,
    flags: i64,
    n_children: i64,
    children: *mut *mut ArrowSchema,
    dictionary: *mut ArrowSchema,
    release: Option<unsafe extern "C" fn(*mut ArrowSchema)>,
    private_data: *mut c_void,
}

#[repr(C)]
struct ArrowArray {
    length: i64,
    null_count: i64,
    offset: i64,
    n_buffers: i64,
    n_children: i64,
    buffers: *mut *const c_void,
    children: *mut *mut ArrowArray,
    dictionary: *mut ArrowArray,
    release: Option<unsafe extern "C" fn(*mut ArrowArray)>,
    private_data: *mut c_void,
}

const ARROW_FLAG_NULLABLE: i64 = 2;
const FORMAT_UINT64: &CStr = c"L";
const FORMAT_LIST: &CStr = c"+l";
const NAME_ITEM: &CStr = c"item";

impl ArrowSchema {
    fn empty() -> Self {
        ArrowSchema {
            format: ptr::null(),
            name: ptr::null(),
            metadata: ptr::null(),
            flags: 0,
            n_children: 0,
            children: ptr::null_mut(),
            dictionary: ptr::null_mut(),
            release: None,
            private_data: ptr::null_mut(),
        }
    }

    /// The format string, or "" when unset.
    fn format(&self) -> &str {
        if self.format.is_null() {
            return "";
        }
        unsafe { CStr::from_ptr(self.format) }.to_str().unwrap_or("")
    }
}

impl ArrowArray {
    fn empty() -> Self {
        ArrowArray {
            length: 0,
            null_count: 0,
            offset: 0,
            n_buffers: 0,
            n_children: 0,
            buffers: ptr::null_mut(),
            children: ptr::null_mut(),
            dictionary: ptr::null_mut(),
            release: None,
            private_data: ptr::null_mut(),
        }
    }

    /// Buffer `i`, or null when absent.
    fn buffer(&self, i: usize) -> *const c_void {
        if self.buffers.is_null() || (i as i64) >= self.n_buffers {
            return ptr::null();
        }
        unsafe { *self.buffers.add(i) }
    }

    /// Whether element `i` (relative to the array offset) is valid.
    fn is_valid(&self, i: usize) -> bool {
        let validity = self.buffer(0) as *const u8;
        if validity.is_null() || self.null_count == 0 {
            return true;
        }
        let bit = self.offset as usize + i;
        unsafe { (*validity.add(bit / 8) >> (bit % 8)) & 1 == 1 }
    }

    /// The `length` u64 values of buffer 1, starting at the array offset.
    fn u64_values(&self) -> &[u64] {
        let values = self.buffer(1) as *const u64;
        if values.is_null() || self.length == 0 {
            return &[];
        }
        unsafe { std::slice::from_raw_parts(values.add(self.offset as usize), self.length as usize) }
    }
}

// --- Exported (Rust-owned) arrays ---

/// The memory behind an exported array: its buffers, the buffer pointer
/// table and, for a list, the child array.
struct ExportedArray {
    values: Vec<u64>,
    offsets: Vec<i32>,
    validity: Option<Vec<u8>>,
    buffer_ptrs: Vec<*const c_void>,
    child: Option<Box<ArrowArray>>,
    child_ptr: Vec<*mut ArrowArray>,
}

unsafe extern "C" fn release_array(array: *mut ArrowArray) {
    let array = unsafe { &mut *array };
    if !array.private_data.is_null() {
        let private = unsafe { Box::from_raw(array.private_data as *mut ExportedArray) };
        if let Some(mut child) = private.child {
            if let Some(release) = child.release {
                unsafe { release(child.as_mut()) };
            }
        }
    }
    array.private_data = ptr::null_mut();
    array.release = None;
}

/// Fill `out` with a Rust-owned array: one buffer of u64 values (primitive)
/// or of i32 offsets plus a child (list), each behind an optional validity
/// bitmap.
fn export_array(
    out: &mut ArrowArray,
    length: usize,
    null_count: usize,
    validity: Option<Vec<u8>>,
    values: Vec<u64>,
    offsets: Vec<i32>,
    child: Option<ArrowArray>,
) {
    let mut private = Box::new(ExportedArray {
        values,
        offsets,
        validity,
        buffer_ptrs: Vec::with_capacity(2),
        child: child.map(Box::new),
        child_ptr: Vec::new(),
    });
    let validity_ptr = private.validity.as_ref().map_or(ptr::null(), |v| v.as_ptr() as *const c_void);
    let data_ptr = if private.child.is_some() {
        private.offsets.as_ptr() as *const c_void
    } else {
        private.values.as_ptr() as *const c_void
    };
    private.buffer_ptrs.push(validity_ptr);
    private.buffer_ptrs.push(data_ptr);
    if let Some(child) = private.child.as_mut() {
        let child_raw: *mut ArrowArray = child.as_mut();
        private.child_ptr.push(child_raw);
    }

    out.length = length as i64;
    out.null_count = null_count as i64;
    out.offset = 0;
    out.n_buffers = 2;
    out.n_children = private.child_ptr.len() as i64;
    out.buffers = private.buffer_ptrs.as_mut_ptr();
    out.children = if private.child_ptr.is_empty() {
        ptr::null_mut()
    } else {
        private.child_ptr.as_mut_ptr()
    };
    out.dictionary = ptr::null_mut();
    out.private_data = Box::into_raw(private) as *mut c_void;
    out.release = Some(release_array);
}

/// A validity bitmap with a bit set for each valid element, or None when
/// every element is valid.
fn validity_bitmap(n: usize, is_valid: impl Fn(usize) -> bool) -> (Option<Vec<u8>>, usize) {
    let mut bitmap = vec![0u8; n.div_ceil(8)];
    let mut nulls = 0;
    for i in 0..n {
        if is_valid(i) {
            bitmap[i / 8] |= 1 << (i % 8);
        } else {
            nulls += 1;
        }
    }
    if nulls == 0 { (None, 0) } else { (Some(bitmap), nulls) }
}

// --- Exported schemas ---

/// The memory behind an exported schema: the child schema and its pointer.
struct ExportedSchema {
    child: Option<Box<ArrowSchema>>,
    child_ptr: Vec<*mut ArrowSchema>,
}

unsafe extern "C" fn release_schema(schema: *mut ArrowSchema) {
    let schema = unsafe { &mut *schema };
    if !schema.private_data.is_null() {
        let private = unsafe { Box::from_raw(schema.private_data as *mut ExportedSchema) };
        if let Some(mut child) = private.child {
            if let Some(release) = child.release {
                unsafe { release(child.as_mut()) };
            }
        }
    }
    schema.private_data = ptr::null_mut();
    schema.release = None;
}

/// Fill `out` with a nullable schema of the given format and optional child.
fn export_schema(out: &mut ArrowSchema, format: &'static CStr, name: Option<&'static CStr>, child: Option<ArrowSchema>) {
    let mut private = Box::new(ExportedSchema { child: child.map(Box::new), child_ptr: Vec::new() });
    if let Some(child) = private.child.as_mut() {
        let child_raw: *mut ArrowSchema = child.as_mut();
        private.child_ptr.push(child_raw);
    }
    out.format = format.as_ptr();
    out.name = name.map_or(ptr::null(), |n| n.as_ptr());
    out.metadata = ptr::null();
    out.flags = ARROW_FLAG_NULLABLE;
    out.n_children = private.child_ptr.len() as i64;
    out.children = if private.child_ptr.is_empty() {
        ptr::null_mut()
    } else {
        private.child_ptr.as_mut_ptr()
    };
    out.dictionary = ptr::null_mut();
    out.private_data = Box::into_raw(private) as *mut c_void;
    out.release = Some(release_schema);
}

fn uint64_schema(name: Option<&'static CStr>) -> ArrowSchema {
    let mut schema = ArrowSchema::empty();
    export_schema(&mut schema, FORMAT_UINT64, name, None);
    schema
}

// --- Slots handed to R ---

/// Array/schema struct pairs at stable heap addresses. Whatever is still
/// unreleased when R collects the slot (an exported array Arrow never
/// imported, an imported one never read) is released then.
struct FfiSlots {
    arrays: Vec<Box<ArrowArray>>,
    schemas: Vec<Box<ArrowSchema>>,
}

impl Drop for FfiSlots {
    fn drop(&mut self) {
        for array in self.arrays.iter_mut() {
            if let Some(release) = array.release {
                unsafe { release(array.as_mut()) };
            }
        }
        for schema in self.schemas.iter_mut() {
            if let Some(release) = schema.release {
                unsafe { release(schema.as_mut()) };
            }
        }
    }
}

/// The slots as an R list: `holder` (the owning external pointer) and the
/// `array` and `schema` addresses as decimal strings, one per slot.
fn slots_to_robj(slots: FfiSlots) -> Robj {
    let arrays: Vec<String> = slots.arrays.iter().map(|a| (a.as_ref() as *const ArrowArray as usize).to_string()).collect();
    let schemas: Vec<String> = slots.schemas.iter().map(|s| (s.as_ref() as *const ArrowSchema as usize).to_string()).collect();
    let holder: Robj = ExternalPtr::new(slots).into();
    list!(holder = holder, array = arrays, schema = schemas).into()
}

fn slots_from_robj(holder: Robj) -> ExternalPtr<FfiSlots> {
    ExternalPtr::<FfiSlots>::try_from(holder).unwrap_or_else(|_| throw_r_error("not an Arrow slot holder"))
}

/// `n` empty slots for the arrow R package to export arrays into.
/// @noRd
/// @keywords internal
#[extendr]
fn arrow_slots_rs(n: i32) -> Robj {
    let n = n.max(0) as usize;
    slots_to_robj(FfiSlots {
        arrays: (0..n).map(|_| Box::new(ArrowArray::empty())).collect(),
        schemas: (0..n).map(|_| Box::new(ArrowSchema::empty())).collect(),
    })
}

/// Check that a slot was filled with the expected format; returns the
/// filled array and schema.
fn filled_slot<'a>(slots: &'a FfiSlots, i: usize, format: &str) -> (&'a ArrowArray, &'a ArrowSchema) {
    let array = slots.arrays[i].as_ref();
    let schema = slots.schemas[i].as_ref();
    if array.release.is_none() || schema.release.is_none() {
        throw_r_error("Arrow did not export the array");
    }
    if schema.format() != format {
        throw_r_error(format!("expected Arrow format '{}', got '{}'", format, schema.format()));
    }
    (array, schema)
}

// --- a5_cell <-> uint64 ---

/// An a5_cell vector as a uint64 array in a new slot.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_arrow_rs(cells: List) -> Robj {
    let cs = CellSlices::from_list(&cells);
    let n = cs.len;
    let mut values = Vec::with_capacity(n);
    let mut any_na = false;
    for i in 0..n {
        let id = cs.get(i);
        any_na |= id.is_none();
        values.push(id.unwrap_or(0));
    }
    let (validity, nulls) = if any_na { validity_bitmap(n, |i| cs.get(i).is_some()) } else { (None, 0) };

    let mut array = Box::new(ArrowArray::empty());
    export_array(&mut array, n, nulls, validity, values, Vec::new(), None);
    let mut schema = Box::new(ArrowSchema::empty());
    export_schema(&mut schema, FORMAT_UINT64, None, None);
    slots_to_robj(FfiSlots { arrays: vec![array], schemas: vec![schema] })
}

/// The cells of every uint64 array exported into `holder`, concatenated.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_from_arrow_rs(holder: Robj) -> List {
    let mut ptr = slots_from_robj(holder);
    let slots: &mut FfiSlots = &mut ptr;
    let total: usize = (0..slots.arrays.len()).map(|i| filled_slot(slots, i, "L").0.length as usize).sum();
    let mut planes: [Vec<u8>; 8] = std::array::from_fn(|_| Vec::with_capacity(total));
    for i in 0..slots.arrays.len() {
        let (array, _) = filled_slot(slots, i, "L");
        for (j, &id) in array.u64_values().iter().enumerate() {
            // A null becomes NA, which is stored as eight 00 bytes.
            let bytes = if array.is_valid(j) { crate::cell_raw::encode(id) } else { [0u8; 8] };
            for (plane, b) in planes.iter_mut().zip(bytes) {
                plane.push(b);
            }
        }
    }
    drop(std::mem::replace(slots, FfiSlots { arrays: Vec::new(), schemas: Vec::new() }));
    raw8_planes_to_list(planes)
}

// --- a5_covering <-> list<uint64> ---

/// An a5_covering vector as a list<uint64> array in a new slot.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_to_arrow_rs(x: List) -> Robj {
    let coverings = read_coverings(&x);
    let n = coverings.len();
    let total: usize = coverings.iter().flatten().map(|c| c.len()).sum();
    if total > i32::MAX as usize {
        throw_r_error("too many cells for an Arrow list<uint64> array");
    }
    let mut values = Vec::with_capacity(total);
    let mut offsets = Vec::with_capacity(n + 1);
    offsets.push(0i32);
    for covering in coverings.iter() {
        if let Some(c) = covering {
            values.extend_from_slice(c);
        }
        offsets.push(values.len() as i32);
    }
    let (validity, nulls) = validity_bitmap(n, |i| coverings[i].is_some());

    let mut child = ArrowArray::empty();
    export_array(&mut child, total, 0, None, values, Vec::new(), None);
    let mut array = Box::new(ArrowArray::empty());
    export_array(&mut array, n, nulls, validity, Vec::new(), offsets, Some(child));
    let mut schema = Box::new(ArrowSchema::empty());
    export_schema(&mut schema, FORMAT_LIST, None, Some(uint64_schema(Some(NAME_ITEM))));
    slots_to_robj(FfiSlots { arrays: vec![array], schemas: vec![schema] })
}

/// The coverings of every list<uint64> array exported into `holder`, as raw
/// vectors of their values (NULL for a null element), concatenated.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_from_arrow_rs(holder: Robj) -> List {
    let mut ptr = slots_from_robj(holder);
    let slots: &mut FfiSlots = &mut ptr;
    let mut out: Vec<Robj> = Vec::new();
    for i in 0..slots.arrays.len() {
        let (array, schema) = filled_slot(slots, i, "+l");
        let child_format = if schema.n_children == 1 { unsafe { &**schema.children }.format() } else { "" };
        if child_format != "L" {
            throw_r_error(format!("expected Arrow list<uint64>, got child format '{}'", child_format));
        }
        let child = unsafe { &**array.children };
        let offsets_ptr = array.buffer(1) as *const i32;
        let n = array.length as usize;
        let offsets: &[i32] = if n == 0 || offsets_ptr.is_null() {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(offsets_ptr.add(array.offset as usize), n + 1) }
        };
        let child_values = child.buffer(1) as *const u64;
        for j in 0..n {
            if !array.is_valid(j) {
                out.push(().into());
                continue;
            }
            let (start, end) = (offsets[j] as usize, offsets[j + 1] as usize);
            if (start..end).any(|k| !child.is_valid(k)) {
                throw_r_error(format!("covering {} contains a null cell", out.len() + 1));
            }
            let mut bytes = Vec::with_capacity(8 * (end - start));
            for k in start..end {
                let v = unsafe { *child_values.add(child.offset as usize + k) };
                bytes.extend_from_slice(&v.to_le_bytes());
            }
            out.push(Robj::from(bytes.as_slice()));
        }
    }
    drop(std::mem::replace(slots, FfiSlots { arrays: Vec::new(), schemas: Vec::new() }));
    List::from_values(out)
}

extendr_module! {
    mod arrow_ffi;
    fn arrow_slots_rs;
    fn a5_cell_to_arrow_rs;
    fn a5_cell_from_arrow_rs;
    fn a5_covering_to_arrow_rs;
    fn a5_covering_from_arrow_rs;
}
