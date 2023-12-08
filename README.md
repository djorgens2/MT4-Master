# MT4-Master
# Copyright 2014, Dennis Jorgenson

# 
# Metatrader 4 code for trade automation in the forex markets.
# 

#---------------------------------------------------------------------------------------------
Stable release(s):
#---------------------------------------------------------------------------------------------

Indicators: All indictors are Zero-Repaint, Event Triggers are real-time

1. Session-v1.[MQ4|EX4] - Time-based Single market session [Daily|Asia|Europe|US] Fractal/Fibonacci Calculation
   - Fractal [Origin|Trend|Term]
   - Session Frames
   - Fibonacci Calculations
   - Event Handling
    
2. Session-v3.[MQ4|EX4] - All market sessions [Daily|Asia|Europe|US]
   - Selected Fractal [Origin|Trend|Term]
   - Session Frames [Asia|Europe|US]
   - Fibonacci Calculations by Selected Fractal
   - Event Handling
    
3. TickMA-v1.[MQ4|EX4] - Range/Motion-based Fractal/Fibonacci Calculation
   - Seperate Indicator Window showing
       - Segments
       - SMAs
       - Linear Regression
   - SMAs calculated on Range-aggregated 'Segments' using supplied Tick Aggregation factor
   - Fractal [Origin|Trend|Term]
   - Linear Regression
   - Event Handling
    
4. TickMA-v3.[MQ4|EX4] - Range/Motion-based Fractal/Fibonacci Calculation
   - In-Chart Fractal
   - SMAs calculated on Range-aggregated 'Segments' using supplied Tick Aggregation factor
   - Fractal [Origin|Trend|Term]
   - Linear Regression
   - Event Handling

5. CPanel-v2[MQ4|EX4] - Order Summary statistics 'panel'
   - Equity/Margin statistics
   - Order Configuration/Operational variables
   - Request queue for Pending Orders
   - Order queue for Open Orders, broken out by Action and summarized by zone.

Experts:

1. man-v1: Legacy Non-integrated release; command-line interface
    - /Include/manual.mqh; manual console command processor
    - /Include/order.mqh; order handling processor


2. man-v2: Integrated release; command-line interface
    - /Include/ordman.mqh; manual console command processor
    - /Include/Class/Order.mqh; order handling processor

#---------------------------------------------------------------------------------------------
Development release(s):
#---------------------------------------------------------------------------------------------

Indicators:

1. TickMA-v2: Working releases to test TickMA-v1
2. Session-v2: Working releases to test Session-v1

Experts:

1. man-v5: (WIP) Current integration release; Full-Auto
   - Classes
     - /Include/Class/Fractal.mqh   ; Fractal Calculations/Events [Origin|Trend|Term] Macro/Meso/Micro 
     - /Include/Class/Session.mqh   ; Data collection for Fractal; time-based collection
     - /Include/Class/TickMA.mqh    ; Data collection for fractal; range-based collection
     - /Include/Class/Order.mqh     ; Comprehensive Order management utilities
     - /Include/Class-CPanel-v2.mqh ; Seperate window indicator displaying Requests/Orders/TickMA detail 
