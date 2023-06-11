// SPDX-License-Identifier: GPL-3.0

pragma solidity >= 0.8.2 < 0.9.0;

contract Auction {
    address public owner;
    uint256 public startingBid;
    uint256 public increment;
    address public highestBidder;
    uint256 public highestBindingBid;
    mapping(address => uint256) public bidderFund;
    bool end;
    bool ownerHasWithdrawn;

    event LogBid(address bidder, uint bid, address highestBidder, uint highestBid, uint highestBindingBid);
    event LogWithdrawal(address withdrawer, address withdrawalAccount, uint amount);
    event LogCanceled();

    constructor(uint256 _startingBid, uint256 _increment) {
        require(_increment != 0 && _startingBid != 0, "Bid increment / starting bid can't be 0");

        owner = msg.sender;
        startingBid = _startingBid;
        increment = _increment;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }

    modifier onlyNotOwner {
        require(msg.sender != owner, "Only auction bidder can call this function");
        _;
    }

    modifier onlyNotEnded {
        require(!end, "Auction has to be running to call this function");
        _;
    }

    modifier onlyEnded {
        require(end, "Auction has to end to call this function");
        _;
    }

    function min (uint256 a, uint256 b) private pure returns(uint256) {
        if (a < b) {
            return a;
        } else {
            return b;
        }
    }

    // Placing bid into the auction
    function placeBid() onlyNotOwner onlyNotEnded public payable returns (bool) {
        require(msg.value != 0, "Can't bid 0");
        require(msg.value >= startingBid, "Can't go lower than starting bid value");

        uint256 newBid = msg.value;
        
        uint256 highestBid = bidderFund[highestBidder];
        require(newBid >= highestBindingBid + increment, "Bid has to be higher than current highest bid");

        bidderFund[msg.sender] = newBid;

        if (newBid <= highestBid) {
            // if the user overbid the binding bid but doesn't over bid the highest bid then only the binding bid gets changed
            highestBindingBid = min(newBid, highestBid);
        } else {
            // if the user is already the highest bidder, then the highest binding bid is left alone and the highest bid gets updated
            if (msg.sender != highestBidder) {
                // if the user was not the highest bidder and has overbid the highest bid this sets them as the new highest bidder
                highestBidder = msg.sender;
                highestBindingBid = min(newBid, highestBid);
            }

            highestBid = newBid;
        }

        emit LogBid(msg.sender, newBid, highestBidder, highestBid, highestBindingBid);
        return true;
    }

    function endAuction() onlyOwner public returns(bool) {
        end = true;
        return true;
    }

    // function to withdraw users' funds in the contract
    function withdraw() onlyEnded public payable returns(bool) {
        address withdrawAccount;
        uint256 withdrawAmount;
        
        if (msg.sender == owner) {
            // auction owner can only withdraw once and withdraws only the highestBindingBid
            require(!ownerHasWithdrawn, "Owner has withdrawn");
            withdrawAccount = highestBidder;
            withdrawAmount = highestBindingBid;
            ownerHasWithdrawn = true;

        } else if (msg.sender == highestBidder) {
            // the highest bidder can only withdraw the difference between their bid and the highestBindingBid
            if (ownerHasWithdrawn) {
                withdrawAmount = bidderFund[highestBidder];
            } else {
                withdrawAmount = bidderFund[highestBidder] - highestBindingBid;
            }

        } else {
            // any other users who participated in the auction but didn't win can withdraw their bidding funds
            withdrawAccount = msg.sender;
            withdrawAmount = bidderFund[withdrawAccount];
        }         
        
        require(withdrawAmount > 0, "No funds to withdraw");
        bidderFund[withdrawAccount] -= withdrawAmount;
        
        require(payable(msg.sender).send(withdrawAmount));

        emit LogWithdrawal(msg.sender, withdrawAccount, withdrawAmount);

        return true;
    }

    function getHighestBid() public view returns(uint256) {
        return bidderFund[highestBidder];
    }

    function myBid() public view returns(uint256) {
        return bidderFund[msg.sender];
    }
}
