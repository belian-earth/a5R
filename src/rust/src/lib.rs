use extendr_api::prelude::*;

mod threading;
mod indexing;
mod boundary;
mod cell_info;
mod hierarchy;
mod grid;
mod traversal;

extendr_module! {
    mod a5R;
    use threading;
    use indexing;
    use boundary;
    use cell_info;
    use hierarchy;
    use grid;
    use traversal;
}
