pub mod brand;
pub mod error;
pub mod handlers;
pub mod middleware;
pub mod models;
pub mod services;
pub mod telemetry;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
