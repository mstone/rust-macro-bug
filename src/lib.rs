#![feature(proc_macro_span)]
use quote::{ToTokens};
use syn::{parse_macro_input, Item, Expr, visit_mut::VisitMut};
struct Parts {}

impl<'ast> VisitMut for Parts {
    fn visit_expr_mut(&mut self, expr: &mut Expr) {
        syn::visit_mut::visit_expr_mut(self, expr);

        let expr_clone = expr.clone();
        *expr = syn::Expr::Block(syn::ExprBlock{
            attrs: vec![],
            label: None,
            block: syn::Block{
                brace_token: syn::token::Brace::default(),
                stmts: vec![syn::Stmt::Expr(expr_clone)],
            },
        });
    }
}

#[proc_macro_attribute]
pub fn bug(args: proc_macro::TokenStream, input: proc_macro::TokenStream) -> proc_macro::TokenStream {
    let _ = args;
    let mut input = parse_macro_input!(input as Item);

    let mut parts = Parts{};
    parts.visit_item_mut(&mut input);
    
    let tokens = input.into_token_stream();
    tokens.into()
}