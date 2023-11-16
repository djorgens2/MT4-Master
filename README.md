# MT4-Master
# Copyright 2014, Dennis Jorgenson

Metatrader 4 code for trade automation in the forex markets.

Stable release(s):

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

Development release(s):
1. TickMA-v2: Working releases to test TickMA-v1
2. Session-v2: Working releases to test Session-v1
