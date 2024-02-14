// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; //The base ERC-20 contract. 
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol"; //To add a max supply of 5B tokens.
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";//To fetch the live MATIC/USD rate

contract MNT is ERC20Capped
{
    AggregatorV3Interface internal dataFeed;

    address public contractOwner;
    uint256 ourCap=5000000000;
    uint256 public capPerAccount=5000;


    // Event to log token purchases with timestamp and current balance of the purchaser
    event TokensPurchased(address indexed buyer, uint256 tokensMinted, uint256 weiPaid, uint256 timestamp, uint256 balance);

    // Event to log minting fees withdrawal with timestamp
    event MintingFeesWithdrawn(uint256 amount, uint256 timestamp);

    // Event to log changes in the capPerAccount variable with previous and new values and timestamp
    event CapPerAccountUpdated(uint256 previousCap, uint256 newCap, uint256 timestamp);


    constructor() ERC20("Monet","MNT")  ERC20Capped(ourCap*(10**uint256(decimals())))
    {
        contractOwner=msg.sender;
        dataFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);//The address of MATIC/usd feed contract (Mumbai Version) from chainlink
        _mint(contractOwner,2500000000*(10**uint256(decimals())));
    }

    modifier onlyOwner()
    {
        require(msg.sender == contractOwner, "Error-MNT_MUMBAI.sol-Ownable");
        _;
    }

    function buyTokensFromContract() external payable
    {
        //This buy function is coded in a way that whatever amount the user sends to this function,
        // they will get an equivalent amount of Monet Tokens in return.

        require(msg.value != 0,"Error-MNT_MUMBAI.sol-Valueless_Transaction");
        // Mint tokens using _mint from ERC20.sol
        uint256 tokensToMint=msg.value*(10**uint256(decimals()))/zTokenPriceInWei() ;

        require(balanceOf(msg.sender) + tokensToMint <= capPerAccount * (10**uint256(decimals())), "Error-MNT_MUMBAI.sol-Exceeds_Max_Balance");

        _mint(msg.sender,tokensToMint);
        emit TokensPurchased(msg.sender, tokensToMint, msg.value, block.timestamp, balanceOf(msg.sender));
    }

    function updateCapPerAccount(uint newCap) public onlyOwner
    {
        uint256 previousCap = capPerAccount;
        capPerAccount=newCap;
        emit CapPerAccountUpdated(previousCap, newCap, block.timestamp);
    }

    function OneMATICInCents() public view returns (int)
    {
        (,int answer,,,) = dataFeed.latestRoundData(); //We care only about the exchange rate, so we ignore other parameters
        
        //The price we get as an output is the exchange rate, with 8 decimal places.
        //Example of that:
        //      Let's consider the price of MATIC to be $0.88.
        //      The output we will get from calling the dataFeed function could be: 88014327
        //      The output means that the exact price of MATIC right now is: $0.88014327
        //      As I don't really want an answer this accurate, I can take only the answer in Cents (the smallest unit of USD)
        //      To get the answer in Cents, I can divide the output I get by 10**6 (The output has 8 decimals, but I care only about the first two decimals)
        return answer/1000000;
        //      So the value I am returning is the price of one MATIC in Cents. In our example, the return value will be 88.
        //      This means that: 1 MATIC = 88 US Cents
    }

    function zTokenPriceInWei() public view returns (uint256)
    {
        //As we set our token price to be equal to $0.02 initially, all this function do is returning the equivalent of $0.02 in MATIC at the moment of calling the function.
        return uint256(2*(10**18))/uint256(OneMATICInCents());
    }

    function WithdrawMintingFees() external onlyOwner
    {
        uint256 fees = address(this).balance;
        // Transfer minting fees to the owner
        payable(contractOwner).transfer(fees);
        emit MintingFeesWithdrawn(fees, block.timestamp);
    }
}