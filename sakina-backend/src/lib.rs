pub mod brand;
pub mod handlers;
pub mod models;
pub mod services;
pub mod middleware;
pub mod error;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
