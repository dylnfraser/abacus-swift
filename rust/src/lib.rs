use std::sync::Mutex;

uniffi::setup_scaffolding!();

/// Error types emitted during Abacus evaluation or state manipulation.
#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum AbacusFfiError {
    #[error("Unknown unit: {0}")]
    UnknownUnit(String),
    #[error("Incompatible dimensions")]
    IncompatibleDimensions,
    #[error("Incompatible function arguments")]
    IncompatibleFunctionArguments,
    #[error("Cannot perform operation on affine units: {0}")]
    AffineUnitOperation(String),
    #[error("Unexpected token: {0}")]
    UnexpectedToken(String),
    #[error("Unexpected end of expression")]
    UnexpectedEnd,
    #[error("Unclosed parenthesis")]
    UnclosedParen,
    #[error("Unclosed bracket in interval")]
    UnclosedBracket,
    #[error("Interval values cannot be passed as function arguments")]
    IntervalInFunction,
    #[error("Invalid date: {0}")]
    InvalidDate(String),
    #[error("Invalid number format: {0}")]
    InvalidNumber(String),
    #[error("Incompatible operator type: {0}")]
    IncompatibleOperatorType(String),
    #[error("Incompatible with conversion: {0}")]
    IncompatibleWithConversion(String),
    #[error("Maximum recursion depth exceeded")]
    RecursionLimitExceeded,
    #[error("Maximum exponent limit exceeded")]
    ExponentLimitExceeded,
    #[error("Undefined variable: {0}")]
    UndefinedVariable(String),
    #[error("Evaluation error: {0}")]
    EvaluationError(String),
    #[error("Currency rate error: {0}")]
    CurrencyRateError(String),
    #[error("Lock error: {0}")]
    LockError(String),
}

impl From<abacus::AbacusError> for AbacusFfiError {
    fn from(err: abacus::AbacusError) -> Self {
        match err {
            abacus::AbacusError::UnknownUnit(u) => AbacusFfiError::UnknownUnit(u),
            abacus::AbacusError::IncompatibleDimensions => AbacusFfiError::IncompatibleDimensions,
            abacus::AbacusError::IncompatibleFunctionArguments => {
                AbacusFfiError::IncompatibleFunctionArguments
            }
            abacus::AbacusError::AffineUnitOperation(op) => {
                AbacusFfiError::AffineUnitOperation(op.to_string())
            }
            abacus::AbacusError::UnexpectedToken(t) => AbacusFfiError::UnexpectedToken(t),
            abacus::AbacusError::UnexpectedEnd => AbacusFfiError::UnexpectedEnd,
            abacus::AbacusError::UnclosedParen => AbacusFfiError::UnclosedParen,
            abacus::AbacusError::UnclosedBracket => AbacusFfiError::UnclosedBracket,
            abacus::AbacusError::IntervalInFunction => AbacusFfiError::IntervalInFunction,
            abacus::AbacusError::InvalidDate(d) => AbacusFfiError::InvalidDate(d),
            abacus::AbacusError::InvalidNumber(n) => AbacusFfiError::InvalidNumber(n),
            abacus::AbacusError::IncompatibleOperatorType(o) => {
                AbacusFfiError::IncompatibleOperatorType(o)
            }
            abacus::AbacusError::IncompatibleWithConversion(c) => {
                AbacusFfiError::IncompatibleWithConversion(c)
            }
            abacus::AbacusError::RecursionLimitExceeded => AbacusFfiError::RecursionLimitExceeded,
            abacus::AbacusError::ExponentLimitExceeded => AbacusFfiError::ExponentLimitExceeded,
            abacus::AbacusError::UndefinedVariable(v) => AbacusFfiError::UndefinedVariable(v),
            abacus::AbacusError::EvaluationError(e) => AbacusFfiError::EvaluationError(e),
            abacus::AbacusError::CurrencyRateError(c) => AbacusFfiError::CurrencyRateError(c),
            _ => AbacusFfiError::EvaluationError(err.to_string()),
        }
    }
}

/// The category of evaluation result.
#[derive(uniffi::Enum, Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResultKind {
    Scalar,
    Interval,
    Date,
    Hash,
}

/// Rich calculation result containing human display string, type kind,
/// raw scalar number (if applicable), and unit symbol (if applicable).
#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct CalculationResult {
    pub display: String,
    pub kind: ResultKind,
    pub scalar_value: Option<f64>,
    pub unit: Option<String>,
}

/// Thread-safe wrapper around `abacus::Abacus`.
#[derive(uniffi::Object)]
pub struct AbacusEngine {
    inner: Mutex<abacus::Abacus>,
}

impl Default for AbacusEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[uniffi::export]
impl AbacusEngine {
    /// Create a new `AbacusEngine` pre-loaded with standard SI units,
    /// currencies, and mathematical constants.
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(abacus::Abacus::standard()),
        }
    }

    /// Evaluates a mathematical expression or variable assignment string.
    pub fn evaluate(&self, expr: &str) -> Result<CalculationResult, AbacusFfiError> {
        let mut engine = self
            .inner
            .lock()
            .map_err(|e| AbacusFfiError::LockError(e.to_string()))?;

        let eval_res = engine.eval_mut(expr)?;

        let display = eval_res.to_display();
        let (kind, scalar_value, unit) = match &eval_res {
            abacus::EvalResult::Scalar(val) => {
                let unit_str = val.unit.display.render();
                let unit = if unit_str.is_empty() {
                    None
                } else {
                    Some(unit_str)
                };
                (ResultKind::Scalar, Some(val.amount()), unit)
            }
            abacus::EvalResult::Interval(interval) => {
                let unit_str = interval.lo.unit.display.render();
                let unit = if unit_str.is_empty() {
                    None
                } else {
                    Some(unit_str)
                };
                (ResultKind::Interval, None, unit)
            }
            abacus::EvalResult::Date(_) => (ResultKind::Date, None, None),
            abacus::EvalResult::Hash(_) => (ResultKind::Hash, None, None),
        };

        Ok(CalculationResult {
            display,
            kind,
            scalar_value,
            unit,
        })
    }

    /// Updates currency exchange rates from a JSON string matching the Frankfurter API response format.
    pub fn update_exchange_rates(&self, json_rates: &str) -> Result<(), AbacusFfiError> {
        let mut engine = self
            .inner
            .lock()
            .map_err(|e| AbacusFfiError::LockError(e.to_string()))?;
        engine.update_rates_from_json(json_rates)?;
        Ok(())
    }

    /// Resets user-defined variables back to standard mathematical constants (pi, e, tau, phi).
    pub fn reset_variables(&self) {
        let mut engine = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        engine.reset_standard_variables();
    }
}
