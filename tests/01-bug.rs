// Check that the simplest use of the #[bug] attribute proc-macro compiles.
use rust_macro_bug_impl::bug;

#[bug]
fn add(a: u64, b: u64) -> u64 { a + b }

pub fn main() {
    assert_eq!(add(1, 2), 3);
}
