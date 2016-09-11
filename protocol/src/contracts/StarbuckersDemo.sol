// pragma solidity ^0.4.1;
import "strings.sol";
//import "BlockOneOracleClient.sol";

contract Starbuckers { //is BlockOneOracleClient(){
    using strings for *;

    // enum
    
    enum State { PENDING, ACTIVE, REJECTED, CANCELLED }
    enum BuySell {BUY, SELL}
    enum TradeState {PENDING, EXECUTED, CANCELLED}
    enum LoanState {ACTIVE, INACTIVE}
    
    // struct
    
    struct Account {
        uint cash;
        uint securitypositions;
        uint margin;
    }
    
    struct Agreement{
        address from;
        address to;
        string securitycode; //e.g. BARC.L
        uint16 haircut; //in basis points, 1 basis point is 0.01% so 16 bit (65536) should be enough
        uint16 lendingrate; // in basis points
        State state;
    }
    
    struct Order {
        address from;
        address to;
        BuySell buysell;
        string securitycode;
        uint16 units;
        uint32 unitprice;
    }

    struct Trade { 
        address buyer;
        address seller;
        string securitycode;
        uint16 units;
        uint32 unitprice;
        TradeState state;
    }
    
    struct Loan {
        address lender;
        address borrower;
        string securitycode;
        uint16 units;
        uint32 ts_start;
        uint32 ts_end;
        uint32 margin;
        uint32 interest_paid;
        LoanState state;
    }    
    

    
    // main variables
        
    uint256 market_price;
    
    mapping (address => Account) accounts;
    Agreement[] public agreements;
    Order[] sellOrders;
    Order[] buyOrders;
    Trade[] trades;
    Loan[] loans;
    
    
    //
    // accounts ////////////////////////////////////////////////////////////////
    //
    
    function getAccountBalance(address _who) constant returns (uint cash, uint securitybalance) {
        cash = accounts[_who].cash;
        securitybalance = accounts[_who].securitypositions;
    }

    //
    // agreements //////////////////////////////////////////////////////////////
    //

    function getAgreement(uint _lendingId) constant returns (address from, address to, string securitycode, uint16 haircut, uint16 lendigrate, State state) {
        var a = agreements[_lendingId];
        from = a.from;
        to = a.to;
        securitycode = a.securitycode;
        haircut = a.haircut;
        lendigrate = a.lendingrate;
        state = a.state;
    }
    
    function getAgreementArraySize() constant returns(uint256 size){
        size = agreements.length;
    }
    
    function proposeLendingAgreement(address _to, string _securitycode, uint16 _haircut, uint16 _lendigrate) {
    
       var a = Agreement(msg.sender, _to, _securitycode, _haircut, _lendigrate, State.PENDING);
       uint256 lendingId = agreements.length; //shortcut because lenght-1 is pos
       agreements.push(a);
       
       LogAgreementStateChange(a.from, a.to, lendingId, State.PENDING);
    }
    
    function  acceptLendingAgreement(uint _lendingId){
        bool found=false;
        var a = agreements[_lendingId];
        if (msg.sender != a.to) throw;
        if (State.PENDING != a.state) throw;
        
        a.state= State.ACTIVE;
        LogAgreementStateChange(a.from, a.to, _lendingId, State.ACTIVE);
    }
    
    function  rejectLendingAgreement(uint _lendingId){
        bool found=false;
        var a = agreements[_lendingId];
        if (msg.sender != a.to) throw;
        if (State.PENDING != a.state) throw;
        
        a.state= State.REJECTED;
        LogAgreementStateChange(a.from, a.to, _lendingId, State.REJECTED);
    }
    //
    // orders //////////////////////////////////////////////////////////////////
    //

    function getOrderArraySize(BuySell bs) constant returns (uint){
        if (BuySell.BUY == bs){
            return buyOrders.length;
        }
        return sellOrders.length;
    }
    
    function getBuyOrder(uint index) constant returns ( address from, address to, BuySell buysell, string securitycode, uint16 units, uint32 unitprice){   
        var o=buyOrders[index];
        to = o.to;
        from = o.from;
        buysell = o.buysell;
        securitycode = o.securitycode;
        units = o.units;
        unitprice = o.unitprice;
        }
        
    function getSellOrder(uint index) constant returns ( address from, address to, BuySell buysell, string securitycode, uint16 units, uint32 unitprice){   
        var o=sellOrders[index];
        to = o.to;
        from = o.from;
        buysell = o.buysell;
        securitycode = o.securitycode;
        units = o.units;
        unitprice = o.unitprice;
    }
    
    function processOrder(address _from, address _to, BuySell _buysell, string _securitycode, uint16 _units, uint32 _unitprice) {
        BuySell bs = BuySell(_buysell);
    
        if (BuySell.BUY == bs){
            buyOrders.push( Order (_from, _to, bs, _securitycode, _units, _unitprice));
        }else{
            sellOrders.push( Order (_from, _to, bs, _securitycode, _units, _unitprice));
        }
    }    

        // if yes: 
        // delete the matched trade from Trades_pending
        // insert the trade into Trades_matched
        // and then call the trade processing function
        
        
        // if not, create hash and append it to Trades_pending

    function matchesOrders(uint256 indexBuy, uint256 indexSell) constant returns (bool matches){
        Order buy = buyOrders[indexBuy];
        Order sell = sellOrders[indexSell];
        if (buy.from != sell.to) return false;
        if (buy.to != sell.from) return false;
        var bcode = buy.securitycode.toSlice();
        var scode = sell.securitycode.toSlice();
        if (!bcode.equals(scode)) return false;
        if (buy.units != sell.units) return false;
        if (buy.unitprice != sell.unitprice) return false;
        return true;
    }
    
    //
    // trades //////////////////////////////////////////////////////////////////
    //
    
    function getTrade(uint index) constant returns (address buyer, address seller, string securitycode, uint16 units, uint32 unitprice, TradeState state){
        
        buyer = trades[index].buyer;
        seller = trades[index].seller;
        securitycode = trades[index].securitycode;
        units = trades[index].units;
        unitprice = trades[index].unitprice;
        state = trades[index].state;
    }
    
    function createTrade(uint256 indexBuy, uint256 indexSell){
        if (!matchesOrders(indexBuy, indexSell)) throw;
        Order buy = buyOrders[indexBuy];
        trades.push(Trade(buy.from, buy.to, buy.securitycode, buy.units, buy.unitprice, TradeState.PENDING));
        delete buyOrders[indexBuy];
        delete sellOrders[indexSell];
    }
    
    function processTrade(uint256 tradeIndex) {
    
        // check trade price
        
        var trade = trades[tradeIndex];
        var trade_price= trade.unitprice;
        var diff = int(market_price - trade_price);
        var deviation = abs(diff) % (trade_price* 100); 
        if (deviation > 5)
          cancelTrade(tradeIndex);  
        
        // does the buyer have enough cash?
        var payment = (trade_price * trade.units);
        if (accounts[trade.buyer].cash < payment) {
            cancelTrade(tradeIndex);  
        }
        
        // does the seller have enough securities
        var seller = accounts[trade.seller];
        if (seller.securitypositions >= trade.units) {
          bookTrade(tradeIndex);
          return;
        }
        
        // check lending agreements
        var available = checkAvailableSecurities(trade.seller);
        
        
        if ((seller.securitypositions + available) >= trade.units) {
            var loan_amount = trade.units - seller.securitypositions;
            processLoans(trade.seller, loan_amount);
            // book the trade
            bookTrade(tradeIndex);
            return; 

        } 
        cancelTrade(tradeIndex);        
    }
    
    function cancelTrade(uint256 tradeIndex) internal {
       trades[tradeIndex].state = TradeState.CANCELLED;
    }
    function bookTrade(uint256 tradeIndex) internal {
       var t = trades[tradeIndex];
       t.state = TradeState.EXECUTED;
       uint cash = t.unitprice * t.units;
       accounts[t.buyer].cash -=  cash;
       accounts[t.seller].cash +=  cash;
       
       accounts[t.buyer].securitypositions +=  t.units;
       accounts[t.seller].securitypositions -=  t.units;
       
       
    }
    
    
    
    //
    // loans ///////////////////////////////////////////////////////////////////
    //

    function checkAvailableSecurities(address seller) constant returns (uint256 available){
        available=0;
        for (uint256 i=0; i< agreements.length; i++){
            var a = agreements[i];
            if (a.to == seller){
                available += accounts[a.from].securitypositions;
   
            }
        }
    }
    
    function processLoans(address seller, uint loan_amount) {
        var remaining=loan_amount;
        for (uint256 i=0; i< agreements.length; i++){
            var a = agreements[i];
            if (a.to == seller){
                var available = accounts[a.from].securitypositions;
                if (available == 0) continue;
                if (available >= remaining){
                    openLoan(i, remaining);
                    return;
                }
                else {
                    openLoan(i, available);
                    remaining -= available;
                }
   
            }
        }
    }
    
    function openLoan (uint i, uint units){
        var r = agreements[i];
        var lender = r.from;
        var borrower = r.to; 
        accounts[lender].securitypositions -= units;
        accounts[borrower].securitypositions += units;
        var margin  = units * market_price * (100+r.haircut)/100;
        accounts[lender].cash += margin;
        accounts[borrower].cash -= margin;
    }
    
    //
    // margin monitoring ///////////////////////////////////////////////////////
    //


    
    // utilities & initialisations /////////////////////////////////////////////
    
    function abs(int signedInt) constant internal returns (uint) {
        if(signedInt < 0) {
            return uint(-signedInt);
        }
        return  uint(signedInt);
    }

    function Starbuckers(){
        //makeOracleRequest("BARC.L", now + 60 seconds);
    }
    
    event LogAgreementStateChange(address indexed _from, address indexed _to, uint indexed _lendingId, State  state);
    event BlockOneOracleClientTest_onOracleRequest(bytes32 _ric, uint _timestamp, uint _requestId);
    event BlockOneOracleClientTest_onOracleResponse(uint _requestId, uint last_trade);
    event BlockOneOracleClientTest_onOracleFailure(uint _requestId, uint _reason);

    function makeOracleRequest(bytes32 _ric, uint _timestamp) {
      //BlockOneOracleClientTest_onOracleRequest(_ric,_timestamp,oracleRequestOneByMarketTime(_ric,_timestamp));
      
    }
    
    function onOracleResponse(uint _requestId, uint ts_millis, bytes32 _ric, uint last_trade, uint bid, uint ask, uint bid_size, uint ask_size){
        market_price = last_trade;
        makeOracleRequest("BARC.L", now + 60 seconds);
    }
} 

contract StarbuckersDemo is Starbuckers{
    address newGuy;
    address newGuy2;
    
    function StarbuckersDemo(){
        log0("init");
        address newGuy = 0xca35b7d915458ef540ade6068dfe2f44e8fa733c;
        address newGuy2 = 0x14723a09acff6d2a60dcdf7aa4aff308fddc160c;

        address owner = msg.sender;
        accounts[owner] = Account(3000, 500, 0);

        init(newGuy, newGuy2);
    }
    
    function demo(){init(newGuy, newGuy2);}
    
    function init(address newGuy, address newGuy2){
        //mapping (string => uint256) secs;
        //secs["BARC.L"] = 1000;
        accounts[newGuy] = Account(1000, 100, 0);
        accounts[newGuy2] = Account(5000, 500, 0);
        proposeLendingAgreement(newGuy2, "BARC.L", 100, 200);
        processOrder(newGuy, newGuy2, BuySell.BUY, "BARC.L", 10, 20);
        processOrder(newGuy2, newGuy, BuySell.SELL, "BARC.L", 10, 20);
        
        createTrade(0,0);
        log0("trade created");
        processTrade(0);
        log0("trade processed");
        //accounts[newGuy].securitypositions["BARC.L"] = 1000;
    }
}
