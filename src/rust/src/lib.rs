use extendr_api::prelude::*;

mod threading;
mod cell_raw;
mod indexing;
mod boundary;
mod cell_info;
mod distance;
mod hierarchy;
mod grid;
mod traversal;
mod regions;

extendr_module! {
    mod a5R;
    use threading;
    use cell_raw;
    use indexing;
    use boundary;
    use cell_info;
    use distance;
    use hierarchy;
    use grid;
    use traversal;
    use regions;
}
