//! Canário da esteira: se isto compila, passa no clippy e no teste no ubuntu-latest,
//! o runner novo não quebra o rust-ci.

fn soma(a: u32, b: u32) -> u32 {
    a + b
}

fn main() {
    println!("canário vivo: {}", soma(2, 2));
}

#[cfg(test)]
mod testes {
    #[test]
    fn soma_funciona() {
        assert_eq!(super::soma(2, 2), 4);
    }
}
