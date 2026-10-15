// We need to forward routine registration from C to Rust
// to avoid the linker removing the static library.

void R_init_a5R_extendr(void *dll);
void a5R_register_api(void);

void R_init_a5R(void *dll) {
    R_init_a5R_extendr(dll);
    a5R_register_api();
}
