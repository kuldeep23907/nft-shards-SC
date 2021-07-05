pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;


import "@openzeppelin/contracts/math/SafeMath.sol";
import "./RaribleERC721.sol";
import "./NFTShardERC20.sol";
import "./Compound.sol";
import "./IChainlinkPriceFeed.sol";

contract NFTShardPoolP is Compound {
    
    using SafeMath for uint256;
    IChainlinkPriceFeed priceFeed;

    enum PoolStatus {active, claim, inactive}

    struct PoolDetails {
        string nftURI;
        uint256 deadline;
        uint256 totalPrice;
        uint256 totalPriceInUSD;
        uint256 totalShards;
        uint256 startTime;
        uint256 soldShardsValueInETH;
        uint256 soldShardsValueInUSD;
        uint256 lendingProfit;
        // uint256 lendingProfitInUSD;
        PoolStatus status;
        address ERC20Token;
        address payable owner;
    }
    
    struct LazyMintingDetails {
        string nftURI;
        uint256 tokenId;
    }

    RaribleERC721 tokenERC721;

    PoolDetails public pool;
    LazyMintingDetails lpool;

    mapping(address => uint256) public  buyers;

    address[] public buyersList;
    
    string public PoolName;

    modifier onlyOwner() {
        require(msg.sender == pool.owner, "Pool owner can only do this");
        _;
    }

    constructor(
        uint256 _id,
        string memory _name,
        string memory _uri, 
        uint256 _totalPrice, 
        uint256 _deadline, 
        uint256 _totalShards, 
        address payable _owner, 
        address _tokenERC721,
        address _priceFeed
        ) Compound() public 
    {
        priceFeed = IChainlinkPriceFeed(_priceFeed);
        PoolName = _name;
        pool.totalPrice = _totalPrice;
        pool.totalPriceInUSD = _totalPrice.mul(priceFeed.getThePrice()).div(10**8);
        pool.deadline = _deadline;
        pool.totalShards = _totalShards;
        pool.startTime = block.timestamp;
        pool.soldShardsValueInETH = 0;
        pool.soldShardsValueInUSD = 0;
        pool.status = PoolStatus.active;
        pool.owner = _owner;
        pool.ERC20Token = address(new NFTShardERC20("Pool tokens", _name));
        pool.lendingProfit = 0;
        // pool.lendingProfitInUSD = 0;
        tokenERC721 = RaribleERC721(_tokenERC721);
        // now minting dummy tokens -- later to be replced by NFTFY returned ERC20 tokens
        NFTShardERC20(pool.ERC20Token).mint(address(this), _totalShards.mul(10**18));
        
        lpool.tokenId = 0;
        lpool.nftURI = _uri;
        pool.nftURI = _uri;
    }
    
    function setTokenId(uint256 _id) public {
        lpool.tokenId = _id;
    }

    function buyShards() public payable returns(uint) {
        require(msg.value > 0 , "Not allowed to borrow 0 shard");
        require(pool.status == PoolStatus.active, "Pool is not active anymore");
        require(block.timestamp <= pool.startTime.add(pool.deadline), "Deadline is over");
        buyers[msg.sender] = buyers[msg.sender].add(msg.value);
        pool.soldShardsValueInETH = pool.soldShardsValueInETH.add(msg.value);
        pool.soldShardsValueInUSD =  pool.soldShardsValueInETH.mul(priceFeed.getThePrice()).div(10**8);
        // deposit to aave/compound
        supplyETH(msg.value);
        if(!buyerAlreadyInList(msg.sender)) {
            buyersList.push(msg.sender);
        }
        
        return msg.value;
    }

    function mintNFTandShard() public onlyOwner returns(address) {
        require(block.timestamp >= pool.startTime.add(pool.deadline), "Deadline not over" );
        require(pool.status == PoolStatus.active, "Pool must be active");

        if(pool.soldShardsValueInETH >= pool.totalPrice) {
            // mint ERC721
            // shard it & get the ERC20Token address
             mintAndTransfer();
            // withdraw from Aave/Compound + interest
            redeemETH();
            pool.lendingProfit = address(this).balance - pool.soldShardsValueInETH;
            // pool.lendingProfitInUSD =  pool.lendingProfit.mul(priceFeed.getThePrice()).div(10**8);
            // set status as claim
            pool.status = PoolStatus.claim;
            // tranfer the shards to buyers
            transferShardsToBuyers();
             // transfer the fixed amount to owner
            pool.owner.transfer(address(this).balance);
            return pool.ERC20Token;
        }

        // withdraw from Aave + interest
        // set status as inactive
        redeemETH();
        pool.lendingProfit = address(this).balance - pool.soldShardsValueInETH;
        // pool.lendingProfitInUSD =  pool.lendingProfit.mul(priceFeed.getThePrice()).div(10**8);
        pool.status = PoolStatus.inactive;
        return address(0);
    }

    function withdrawETH() public {
        require(block.timestamp >= pool.startTime.add(pool.deadline), "Deadline not over");
        require(pool.status == PoolStatus.inactive, "Pool must be inactive");
        require(buyers[msg.sender] > 0, "No shards bought");
        // add profit to it once aave/compound is there
        uint256 profit = (buyers[msg.sender]).mul(pool.lendingProfit).div(pool.soldShardsValueInETH);
        msg.sender.transfer(buyers[msg.sender].add(profit));
        buyers[msg.sender] = 0;
    }

    function closePool() public onlyOwner returns(bool) {
        // some logic
        return true;
    }

    function getBuyersCount() public view returns(uint256 count) {
        return buyersList.length;
    }

    function buyerAlreadyInList(address searchUser) internal view  returns(bool){
        for(uint256 i = 0; i< buyersList.length; i++) {
            if(buyersList[i] == searchUser) {
                return true;
            }
        }
        return false;
    }

    function transferShardsToBuyers() internal {
        for(uint256 i = 0; i< buyersList.length; i++) {
            uint256 share = (buyers[buyersList[i]]).mul(pool.totalShards).div(pool.soldShardsValueInETH); 
            NFTShardERC20(pool.ERC20Token).transfer(buyersList[i], share.mul(10**18));    
        }
    }
    
     function mintAndTransfer() internal {
            
            // bytes memory tid = toBytes(address(this));
            // bytes memory tid2 = toBytes(1);
            
            bytes[] memory signs = new bytes[](1);
            signs[0] = "0x";
            
            RaribleERC721.Part[] memory creators = new RaribleERC721.Part[](1);
            creators[0] = RaribleERC721.Part(address(this),10000);
            
            RaribleERC721.Part[] memory extras = new RaribleERC721.Part[](1);
            extras[0] = RaribleERC721.Part(address(this),10000);
            
            tokenERC721.mintAndTransfer(
                RaribleERC721.Mint721Data(
                     lpool.tokenId,
                     lpool.nftURI,
                     creators,
                     extras,
                     signs
            ),
                address(this)
            );
    }
    
    // function toBytes(address a) public pure returns (bytes memory) {
    //     return abi.encodePacked(a);
    // } 
    
    //  function toBytes(uint256 a) public pure returns (bytes memory) {
    //     return abi.encodePacked(a);
    // } 
    
}
