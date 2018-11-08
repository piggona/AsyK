pragma solidity ^0.4.22;

contract Time_Tactics {
    function give_tactics(uint require_repayment_time,uint deadline,uint set_time) public returns (uint);
}
contract Repayment_Tactics {
    function give_tactics(uint total_balance,uint remain_balance,bool state_transaction_accomplish,uint set_repayment) public returns (uint, bool, uint);
}
contract Fail_Tactics {
    function give_tactics(uint total_balance,uint require_repayment) public returns (uint);
}

contract simple_fail_Tac is Fail_Tactics {
    function give_tactics(uint total_balance,uint require_repayment) public returns (uint) {
        uint new_balance;
        new_balance = total_balance - require_repayment;
        return new_balance;
    }
}
contract simple_time_Tac is Time_Tactics {
    function give_tactics(uint require_repayment_time,uint deadline,uint set_time) public returns (uint) {
        uint next_repayment_time;
        uint new_require_time;
        if (require_repayment_time == 0){
            new_require_time = deadline;
            return new_require_time;
        }
        else{
            if (set_time == 0){
                next_repayment_time = require_repayment_time + 0;
                return next_repayment_time;
            }
            else{
                return set_time;
            }
        }
    }
}
contract simple_repayment_Tac is Repayment_Tactics {
    function give_tactics(uint total_balance,uint remain_balance,bool state_transaction_accomplish,uint set_repayment) public returns (uint ,bool, uint)
    {
        if(state_transaction_accomplish)
        {
            if (set_repayment != 0)
            {
                return (set_repayment, false, total_balance);
            }
            else {
                return (0,true,0);
            }
        }
        else
        {
            if (total_balance == remain_balance)
            {
                return (total_balance,false,total_balance);
            }
            else
            {
                return (total_balance,false,total_balance);
            }
        }
    }
}
contract Asyk {
    struct UserData {
        string product;
        address lender_addr;
        uint deadline;//时间戳
        uint require_repayment_time;//是一个时间戳
        uint previous_time;
        uint total_balance;//单位是wei
        uint remain_balance;
        uint require_repayment;
        uint previous_repayment;
        bool state_transaction_accomplish;
        bool state_repayment_ack;
        bool state_accomplish;
        bool state_failed;
    }
    struct TacData {
        Time_Tactics TimeTactics;
        Repayment_Tactics RepaymentTactics;
        Fail_Tactics FailTactics;
    }
    mapping(string => UserData) private user;
    mapping(string => TacData) private products;
    address private pool_addr;
    address private controller_addr;

    event Transaction_accomplished (string user_id, address lender, uint need_balance);
    event Repayment_notify (string user_id, address lender, uint require_repayment_time);

    modifier visitorFunc {
        require(pool_addr == msg.sender||controller_addr == msg.sender,"Sender Not Authorized");
        _;
    }
    modifier poolFunc {
        require(pool_addr == msg.sender,"Sender Not Authorized");
        _;
    }
    modifier controllerFunc {
        require(controller_addr == msg.sender,"Sender Not Authorized");
        _;
    }
    constructor(
    address set_pool_addr,
    address set_controller_addr) public{
        pool_addr = set_pool_addr;
        controller_addr = set_controller_addr;
    }
    function add_products(string product_id,Time_Tactics set_time_tactics_addr,Repayment_Tactics set_repayment_tactics_addr,Fail_Tactics set_fail_tactics_addr) public controllerFunc {
        TacData storage tacData = products[product_id];
        tacData.TimeTactics = set_time_tactics_addr;
        tacData.RepaymentTactics = set_repayment_tactics_addr;
        tacData.FailTactics = set_fail_tactics_addr;
    }
    function add_user(string user_id,string product_id,address set_lender_addr,uint set_balance) public poolFunc {
        UserData storage userData = user[user_id];
        userData.lender_addr = set_lender_addr;
        userData.total_balance = set_balance;
        userData.product = product_id;
        userData.remain_balance = set_balance;
        userData.require_repayment_time = 0;
        userData.previous_repayment = 0;
        userData.previous_time = 0;
        userData.state_transaction_accomplish = false;
        userData.state_repayment_ack = false;
        userData.state_accomplish = false;
        userData.state_failed = false;
    }

    function mortgage(string user_id) external payable {
        UserData storage userData = user[user_id];
        address lender_addr = userData.lender_addr;
        require(lender_addr == msg.sender,"Sender Not Authorized");
        assert(msg.value > 1 ether);
        uint amount = msg.value;
        require(amount >= userData.total_balance,"Value of mortgage is not enough");
        emit Transaction_accomplished(user_id, msg.sender, amount);
        TacData storage tacData = products[userData.product];
        Time_Tactics myTimeTactics = tacData.TimeTactics;
        Repayment_Tactics myRepaymentTactics = tacData.RepaymentTactics;
        userData.require_repayment_time = myTimeTactics.give_tactics(userData.require_repayment_time,userData.deadline,0);
        (userData.require_repayment,,userData.remain_balance) = myRepaymentTactics.give_tactics(userData.total_balance,userData.remain_balance,userData.state_transaction_accomplish,0);
        userData.state_transaction_accomplish = true;
    }

    function deadline_set(string user_id,uint set_deadline) public poolFunc {
        UserData storage userData = user[user_id];
        userData.deadline = set_deadline;
    }

    function repayment(string user_id) public poolFunc {
        UserData storage userData = user[user_id];
        require(now >= (userData.require_repayment_time - 5 days));
        emit Repayment_notify(user_id, userData.lender_addr, userData.total_balance);
        userData.state_repayment_ack = true;
    }
    function repayment_suc(string user_id) public controllerFunc {
        bool finish = false;
        UserData storage userData = user[user_id];
        TacData storage tacData = products[userData.product];
        Time_Tactics myTimeTactics = tacData.TimeTactics;
        Repayment_Tactics myRepaymentTactics = tacData.RepaymentTactics;
        if (userData.previous_repayment != 0)
        {
            userData.require_repayment = userData.previous_repayment;
            userData.previous_repayment = 0;
        }
        else{
            (userData.require_repayment,finish,userData.remain_balance) = myRepaymentTactics.give_tactics(userData.total_balance,userData.remain_balance,userData.state_transaction_accomplish,0);
        }
        if (userData.previous_time != 0){
            userData.require_repayment_time = userData.previous_time;
            userData.previous_time = 0;
        }
        else{
            userData.require_repayment_time = myTimeTactics.give_tactics(userData.require_repayment_time,userData.deadline,0);
        }
        if(finish){
            userData.state_accomplish = true;
            userData.lender_addr.transfer(userData.total_balance);
        }
    }

    function repayment_fail(string user_id) public controllerFunc {
        UserData storage userData = user[user_id];
        uint new_balance;
        userData.state_failed = true;
        TacData storage tacData = products[userData.product];
        Fail_Tactics myFailTactics = tacData.FailTactics;
        new_balance = myFailTactics.give_tactics(userData.total_balance,userData.require_repayment);
        pool_addr.transfer(userData.total_balance - new_balance);
        userData.total_balance = new_balance;
        if (userData.total_balance == 0)
        {
            userData.state_accomplish = true;
        }
        userData.state_failed = false;
    }
    function add_loan(uint set_time,uint set_repayment,string user_id) public controllerFunc {
        UserData storage userData = user[user_id];
        userData.previous_repayment = userData.require_repayment;
        TacData storage tacData = products[userData.product];
        Time_Tactics myTimeTactics = tacData.TimeTactics;
        Repayment_Tactics myRepaymentTactics = tacData.RepaymentTactics;
        (userData.require_repayment,,userData.remain_balance) = myRepaymentTactics.give_tactics(userData.total_balance,userData.remain_balance,userData.state_transaction_accomplish,set_repayment);
        userData.previous_time = userData.require_repayment_time;
        userData.require_repayment_time = myTimeTactics.give_tactics(userData.require_repayment_time,userData.deadline,set_time);
    }


    function get_balance(string user_id) public view returns (uint) {
        UserData storage userData = user[user_id];
        require(userData.lender_addr == msg.sender||pool_addr == msg.sender||controller_addr == msg.sender,"Sender Not Authorized");
        return userData.remain_balance;
    }
    function get_lender_addr(string user_id) public view visitorFunc returns (address) {
        UserData storage userData = user[user_id];
        return userData.lender_addr;
    }
    function get_deadline(string user_id) public view visitorFunc returns (uint){
        UserData storage userData = user[user_id];
        return userData.deadline;
    }
    function get_require_payment_time(string user_id) public view visitorFunc returns (uint) {
        UserData storage userData = user[user_id];
        return userData.require_repayment_time;
    }
    function get_require_payment(string user_id) public view visitorFunc returns (uint) {
        UserData storage userData = user[user_id];
        return userData.require_repayment;
    }
    function get_total_balance(string user_id) public view returns (uint){
        UserData storage userData = user[user_id];
        require(userData.lender_addr == msg.sender||pool_addr == msg.sender||controller_addr == msg.sender,"Sender Not Authorized");
        return userData.total_balance;
    }
    function get_state_transaction_accomplish(string user_id) public view visitorFunc returns (bool){
        UserData storage userData = user[user_id];
        return userData.state_transaction_accomplish;
    }
    function get_state_repayment_ack(string user_id) public view visitorFunc returns (bool) {
        UserData storage userData = user[user_id];
        return userData.state_repayment_ack;
    }
    function get_state_accomplish(string user_id) public view visitorFunc returns (bool){
        UserData storage userData = user[user_id];
        return userData.state_accomplish;
    }
    function get_state_failed(string user_id) public view visitorFunc returns (bool) {
        UserData storage userData = user[user_id];
        return userData.state_failed;
    }
}
