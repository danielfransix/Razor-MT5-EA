# Razor MT5 EA - Development Plan

## System Overview

### Core Trading Philosophy
The Razor EA implements a **retracement trading strategy** based on the market principle that significant single-candle movements often result in temporary price reversals. The system capitalizes on these short-term corrections by entering positions that anticipate immediate retracements or continuation patterns.

### Key Market Assumptions
1. **Overextension Principle**: Large single-candle moves indicate temporary market overextension
2. **Retracement Tendency**: Markets naturally pull back after significant directional moves
3. **Momentum Continuation**: After retracement, price often continues in the original direction
4. **Scalping Opportunity**: Quick entries and exits can capture these micro-movements

## System Architecture Requirements

### 1. Market Monitoring Engine
**What it does**: Continuously monitors price action on specified timeframes to detect trigger conditions.

**Core Requirements**:
- Real-time candle analysis on user-defined timeframes
- Calculate pure price distance movement for each completed candle
- Compare movement against user-defined trigger threshold
- Maintain state awareness to prevent duplicate signals from same candle
- Handle multiple timeframe monitoring simultaneously if needed

**Key Metrics to Track**:
- Candle open/high/low/close prices
- Pure price movement distance (High - Low)
- Direction of movement (bullish/bearish)
- Timestamp of trigger events

### 2. Dual Trading Mode System
**What it does**: Provides two distinct trading approaches based on different market assumptions.

#### Mode 1: Counter-Trend (Immediate Retracement)
**Philosophy**: Bet against the large move, expecting immediate reversal
**Execution Logic**:
- Large bearish candle → Immediate BUY market order
- Large bullish candle → Immediate SELL market order
- Entry timing: As soon as trigger condition is met
- Position type: Market orders for instant execution

#### Mode 2: Trend-Following (Delayed Entry)
**Philosophy**: Wait for retracement, then follow the original trend
**Execution Logic**:
- Large bearish candle → Place SELL LIMIT above current price
- Large bullish candle → Place BUY LIMIT below current price
- Entry timing: When price retraces and hits limit order
- Position type: Pending limit orders

### 3. Dynamic Configuration Management System
**What it does**: Provides comprehensive user control over all trading parameters with real-time updates to existing positions.

**Required Parameters** (with brief descriptions):
- **Timeframe Selection**: M1, M5, M15, M30, H1, H4, D1 - Chart timeframe to monitor for trigger signals
- **Trigger Distance**: Pure price distance (5 decimal precision) - Minimum candle movement to trigger trades
- **Trading Mode**: Counter-trend vs Trend-following - Direction of trade relative to trigger candle
- **Limit Order Distance**: For Mode 2, distance from current price - How far to place pending orders
- **Stop Loss Configuration**: Fixed distance or trailing parameters - Loss protection method and distance
- **Take Profit Distance**: Fixed pure price distance - Profit target distance from entry
- **Position Sizing**: Fixed lot size or equity risk percentage - Trade size determination method
- **Minimum Equity**: Minimum account equity to continue trading - Safety threshold for new positions

**Dynamic Update Feature**: All parameter changes immediately affect existing positions (TP/SL recalculation and modification)

### 4. Risk Management Engine
**What it does**: Implements comprehensive position protection and risk control.

#### Stop Loss Implementation
**Option A - Fixed Stop Loss**:
- Calculate SL price based on fixed distance from entry
- Set SL immediately upon position opening
- Distance specified in pure price units

**Option B - Ghost Trailing Stop Loss**:
- Initialize trailing SL at specified distance from entry
- Update SL price as position moves favorably
- Trail continuously until SL is hit or TP is reached
- No minimum trailing distance (ghost trailing)
- SL follows price movement without restrictions

#### Take Profit Implementation
- Fixed distance from entry price
- Calculated in pure price units
- Set immediately upon position opening
- No modification after initial setting

### 5. Position Management System
**What it does**: Handles order execution, modification, and lifecycle management.

**Core Functions**:
- Execute market orders for Mode 1
- Place and manage pending orders for Mode 2
- Monitor position status and P&L
- Handle order modifications (SL/TP updates)
- Manage position closure conditions
- Track position statistics and performance

### 6. Price Calculation Engine
**What it does**: Handles all price-related calculations with high precision.

**Requirements**:
- Work exclusively in pure price units (not pips/points)
- Maintain 5-decimal precision for all calculations
- Convert between different price formats as needed
- Handle symbol-specific price characteristics
- No spread consideration in calculations (use raw prices)

## Step-by-Step Development Plan

### Phase 1: Foundation Setup
**Objective**: Establish basic EA structure and configuration framework

#### Step 1.1: EA Template Creation
- Create basic MT5 EA file structure
- Implement OnInit(), OnTick(), OnDeinit() functions
- Set up basic error handling and logging
- Establish EA identification and version control

#### Step 1.2: Input Parameter System
- Define all user-configurable parameters with detailed descriptions
- Implement input validation and range checking
- Create parameter grouping for better UI organization
- Add comprehensive parameter descriptions explaining exact functionality
- Implement dynamic parameter update system for real-time changes

#### Step 1.3: Symbol and Market Information Handler
- Implement symbol specification detection for single symbol operation
- Calculate point values and decimal precision
- Handle current symbol characteristics only
- Establish price normalization functions without spread consideration

### Phase 2: Market Monitoring Implementation
**Objective**: Build the core candle analysis and trigger detection system

#### Step 2.1: Timeframe Management
- Implement timeframe selection logic
- Create candle data retrieval functions
- Handle timeframe switching and validation
- Establish candle completion detection

#### Step 2.2: Trigger Detection Engine
- Calculate pure price movement for each candle
- Compare movement against trigger threshold
- Determine movement direction (bullish/bearish)
- Implement trigger state management to prevent duplicates

#### Step 2.3: Signal Generation System
- Create signal objects/structures
- Implement signal validation logic
- Add signal filtering and confirmation
- Establish signal logging and debugging

### Phase 3: Trading Mode Implementation
**Objective**: Build both counter-trend and trend-following execution systems

#### Step 3.1: Mode 1 - Counter-Trend System
- Implement immediate market order execution
- Create opposite-direction position logic
- Handle order timing and slippage considerations
- Add execution confirmation and error handling

#### Step 3.2: Mode 2 - Trend-Following System
- Implement limit order placement logic
- Calculate optimal limit order distances
- Create pending order management system
- Handle order expiration and modification

#### Step 3.3: Mode Selection and Switching
- Create mode selection interface
- Implement runtime mode switching capability
- Add mode-specific parameter validation
- Establish mode state persistence

### Phase 4: Risk Management Implementation
**Objective**: Build comprehensive position protection systems

#### Step 4.1: Stop Loss System
- Implement fixed SL calculation and placement
- Create trailing SL logic and update mechanism
- Handle SL modification and error scenarios
- Add SL type selection and switching

#### Step 4.2: Take Profit System
- Implement TP calculation based on pure price distance
- Create TP placement and modification logic
- Handle TP execution and confirmation
- Add dynamic TP adjustment for configuration changes

#### Step 4.3: Position Sizing and Risk Management
- Implement fixed lot size option
- Create equity percentage-based lot size calculation
- Enforce minimum lot size of 0.01
- Add minimum equity threshold for position management
- Implement equity-based position closure system

### Phase 5: Position Management and Monitoring
**Objective**: Build comprehensive position lifecycle management

#### Step 5.1: Order Execution Engine
- Create robust order sending functions
- Implement retry logic for failed orders
- Handle partial fills and order modifications
- Add execution speed optimization

#### Step 5.2: Position Monitoring System
- Track all open positions and pending orders
- Monitor P&L and position status
- Implement position update and modification logic
- Create position closure management

#### Step 5.3: Performance Tracking
- Implement trade statistics collection
- Create performance metrics calculation
- Add win/loss ratio and profit tracking
- Establish reporting and analysis features

### Phase 6: Chart Interface and Controls
**Objective**: Add visual interface and position management controls

#### Step 6.1: Chart Information Display
- Create on-chart information panel showing EA status
- Display current configuration parameters
- Show active positions and P&L information
- Add real-time trigger monitoring display

#### Step 6.2: Chart Control Buttons
- Implement "Kill All Positions" button for EA-specific positions
- Add "Kill All Buys" button for long positions only
- Add "Kill All Sells" button for short positions only
- Create button styling and positioning system

#### Step 6.3: Dynamic Configuration Interface
- Implement real-time parameter modification system
- Create immediate position update mechanism for config changes
- Add configuration change confirmation and validation
- Establish parameter persistence across EA restarts

### Phase 7: Final Integration and Deployment
**Objective**: Complete system integration and prepare for live deployment

#### Step 7.1: System Integration
- Integrate all components into cohesive system
- Validate complete workflow functionality
- Test dynamic configuration updates
- Verify chart interface and controls

#### Step 7.2: Performance Validation
- Ensure maximum reactivity and responsiveness
- Validate real-time trigger detection
- Test position management under high frequency
- Confirm dynamic parameter updates work correctly

#### Step 7.3: Deployment Preparation
- Finalize EA compilation settings
- Prepare user documentation
- Create configuration templates
- Establish deployment checklist

## Technical Considerations

### Data Precision Requirements
- All price calculations must maintain 5-decimal precision
- Use appropriate data types to prevent precision loss
- Implement rounding and normalization functions
- Handle floating-point arithmetic carefully

### Performance Requirements
- System must respond to triggers with maximum reactivity (no artificial delays)
- Prioritize responsiveness over resource optimization
- Real-time parameter updates without performance degradation
- Immediate position modifications upon configuration changes

### Error Handling Requirements
- Graceful handling of connection losses
- Recovery from order execution failures
- Validation of all user inputs
- Comprehensive logging of all system events

### Security and Stability
- Prevent unauthorized parameter modification
- Implement position limit safeguards
- Add emergency stop mechanisms
- Ensure system stability under high volatility

## Success Criteria

### Functional Requirements
- ✅ Accurate trigger detection on specified timeframes
- ✅ Reliable execution of both trading modes
- ✅ Precise risk management implementation
- ✅ Comprehensive configuration options
- ✅ Stable performance under various market conditions

### Performance Requirements
- ✅ Sub-100ms response time to triggers
- ✅ 99.9% uptime during market hours
- ✅ Accurate price calculations with 5-decimal precision
- ✅ Efficient resource utilization
- ✅ Optimized for single symbol operation with maximum reactivity

### User Experience Requirements
- ✅ Intuitive parameter configuration
- ✅ Clear visual feedback and status indicators
- ✅ Comprehensive logging and reporting
- ✅ Easy mode switching and customization
- ✅ Reliable operation with minimal intervention

This development plan provides a comprehensive roadmap for building the Razor MT5 EA while maintaining focus on the 'what' rather than the 'how', allowing developers flexibility in implementation approaches while ensuring all critical requirements are addressed.