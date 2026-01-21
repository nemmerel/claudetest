# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains a financial and economic data analysis project using Stata. The primary focus is on analyzing S&P 500 constituent data, replicating and extending Shiller valuation models, and performing forward-looking earnings estimates and house price analysis.

## Project Structure

### Data Files (`/data`)
- `sp500_ticker_start_end.csv` - S&P 500 constituent ticker data with start/end dates
- `shiller_import.xls` - Shiller index data (price, dividends, earnings, CPI)
- `r_data.xlsx` - Interest rate data
- `hp_data.xlsx` - House price data
- Various `.dta` files - Processed Stata datasets including CRSP data, IBES estimates, and merged datasets

### Analysis Scripts (`/dofiles`)
- `interest_rates.do` - Main Stata analysis script that:
  - Imports and processes S&P 500 constituent data
  - Replicates Shiller (1979) valuation analysis
  - Extends Shiller methodology to 2021
  - Performs forward-looking EPS estimation using IBES data
  - Conducts house price analysis
  - Generates valuation estimates under different interest rate scenarios

### Output (`/graphs`)
Generated visualizations including:
- `shiller_replicate.png` - Replication of original Shiller graph
- `shiller_2021.png` - Extended Shiller analysis through 2021
- `shiller_undetrend_2021.png` - Undetrended price series
- Various earnings-based variations (`eshiller_*.png`)
- Log-transformed series (`shiller_lundetrend_2021.png`, `shiller_elundetrend_2021.png`)

## Analysis Steps

The main do-file (`interest_rates.do`) uses global step flags to control execution:
- `step_0` - Data import, Shiller replication and extension, house price analysis
- `step_1` - CRSP and IBES data processing, forward-looking valuation estimates

## GitHub Actions Workflows

1. **Claude Code Review** (`.github/workflows/claude-code-review.yml`)
   - Automatically runs on pull requests
   - Uses the `code-review` plugin from the claude-code-plugins marketplace
   - Requires `CLAUDE_CODE_OAUTH_TOKEN` secret

2. **Claude PR Assistant** (`.github/workflows/claude.yml`)
   - Triggers when `@claude` is mentioned in issues or pull requests
   - Has read access to CI results on PRs

## Working with This Project

- The main analysis is executed via Stata using `dofiles/interest_rates.do`
- Output paths are configured via global macros to point to `/data` and `/graphs` directories
- The analysis replicates academic work on equity valuation and extends it with forward-looking estimates
