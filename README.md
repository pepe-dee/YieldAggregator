# YieldAggregator

A composable yield aggregation contract for the Stacks blockchain. YieldAggregator enables users to pool STX and have it automatically distributed across multiple yield-generating strategies with customizable weight allocations.

## Overview

YieldAggregator acts as a protocol layer that:
- Aggregates user deposits into a single vault
- Distributes capital across multiple yield strategies based on admin-configured weights
- Mints shares representing user ownership
- Allows users to withdraw by redeeming shares for their proportional asset allocation

## Key Features

✅ **Multi-Strategy Support** — Register and manage multiple yield strategies via a composable trait interface  
✅ **Weighted Distribution** — Admin controls capital allocation across strategies using configurable weights  
✅ **Share-Based Accounting** — 1:1 share minting allows accurate ownership tracking and proportional withdrawals  
✅ **Admin Controls** — Secure strategy registration and weight management with admin authorization  
✅ **Error Handling** — Comprehensive validation with 9 distinct error codes  

## Architecture

### Core Components

**Strategy Trait**
```lisp
(define-trait strategy-trait
  (
    (receive-deposit (uint) (response bool uint))
    (withdraw-to (uint principal) (response bool uint))
    (report-balance () (response uint uint))
  )
)
