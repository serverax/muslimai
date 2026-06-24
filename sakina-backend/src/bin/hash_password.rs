//! One-off utility: `cargo run --bin hash_password -- 'YourPassword'`
fn main() {
    let password = std::env::args().nth(1).unwrap_or_else(|| {
        eprintln!("usage: hash_password <password>");
        std::process::exit(1);
    });
    use argon2::password_hash::{PasswordHasher, SaltString};
    use argon2::Argon2;
    use rand_core::OsRng;
    let salt = SaltString::generate(&mut OsRng);
    let hash = Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .expect("hash password");
    println!("{}", hash);
}
