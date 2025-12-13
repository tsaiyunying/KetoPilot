# Food Search & Food Details Integration (USDA)

## Overview

This feature adds an end-to-end food search and food details flow integrated with the USDA SQLite database.
Users can search foods directly from the Food Diary page and view detailed nutrition information
designed for keto macro tracking.

---

## What Was Implemented

### 1. Food Search Page
- Implemented a food search UI backed by the local USDA SQLite database
- Supports keyword-based food name search
- Displays search results with food name and USDA food code

### 2. Food Details Page
- Added a food details page for selected food items
- Displays keto-relevant nutrition values per **100g**:
  - Calories
  - Protein
  - Fat
  - Net Carbs
- Food data is queried using USDA `food_code`
