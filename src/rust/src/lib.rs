use extendr_api::prelude::*;

mod threading;
mod hilo;
mod indexing;
mod boundary;
mod cell_info;
mod distance;
mod hierarchy;
mod grid;
mod traversal;

extendr_module! {
    mod a5R;
    use threading;
    use hilo;
    use indexing;
    use boundary;
    use cell_info;
    use distance;
    use hierarchy;
    use grid;
    use traversal;
}
