// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "./interface/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ISwapRouter.sol";
import "./interface/ISwapPair.sol";
import "./interface/ISwapFactory.sol";
import "./Counters.sol";
import "./DoubleEndedQueue.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MintDBTC is Ownable, ReentrancyGuard {
    using EnumerableMap for EnumerableMap.UintToUintMap;
    EnumerableMap.UintToUintMap private HashFEDay;
    EnumerableMap.UintToUintMap private TFEDay;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    EnumerableMap.AddressToUintMap private UserNCPower;
    EnumerableMap.AddressToUintMap private UserReceivesStartDate;
    EnumerableMap.AddressToUintMap private tokenPower;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableMap.AddressToUintMap private GiveawayUserNCPower;
    uint256 private constant MAX = ~uint256(0);
    using BitMaps for BitMaps.BitMap;
    mapping(address => BitMaps.BitMap) private UserReceiveRecord;
    BitMaps.BitMap private UBA;

    BitMaps.BitMap private tokenAllow;

    ISwapRouter public _Sr;

    address public usd;

    TokenDistributor public _tokenDistributor;
    TokenDBTCDistributor public _tokenDBTCDistributor;

    uint256 public _HashFactor = 1;
    uint256 public _LastUpdateTimestamp = 0;
    uint256 public _lastHashFactor = 0;

    uint256 public _ltp = 0;
    uint256 public _ltpTimestamp = 0;

    uint256 public _ds = 1 days;

    IERC20 public D;

    uint256 public _startDay;

    uint256 public _mea = 10 ether;

    uint256 public mintedDBTC = 0;

    ISwapFactory public swapFactory;

    address public _dead = 0x000000000000000000000000000000000000dEaD;

    address public _funderAddress;

    uint256 public _updateDays = 7;

    uint256 public _allPrice;

    uint256 public _drawDBTCFee;

    bool public _isDrawDBTCFee = false;

    uint256 public _MPI = 3000 ether;

    uint256 public _miP = 100 ether;

    mapping(address => uint256) public _UPI;

    uint256[] public _referReward = [12, 5, 3, 2, 2, 2, 1, 1, 1, 1];

    uint256 public _referLength = 9;

    bool public _startDrawDBTC = false;


    struct TInfoS {
        bool isBurn;
        bool isSwap;
        bool isToFunder;
        bool isSwapBurnDBTC;
        uint256 burnFee;
        uint256 swapFee;
        uint256 toFunder;
        uint256 _SBF;
        uint256 SlippageFee;
        address pair;
    }


    mapping(address => EnumerableSet.AddressSet) private _refersMap;
    mapping(address => EnumerableSet.AddressSet) private _refersGood;

    mapping(address => TInfoS) public tInfo;

    mapping(address => uint256) public _referAllPower;
    address public dp;

    mapping(uint256 => address) public _id_to_address;

    using Counters for Counters.Counter;
    Counters.Counter private _addressId;
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;
    struct ReferM {
        DoubleEndedQueue.Uint256Deque _referDeque;
        uint256 _referId;


    }

    mapping(address => uint256) public referPowerMap;

    mapping(address => ReferM) private _referMss;

    constructor() Ownable(msg.sender){
        _Sr = ISwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        usd = 0x55d398326f99059fF775485246999027B3197955;
        _tokenDistributor = new TokenDistributor(usd);
        dp = 0x21dfe97101717ed7f562da5D1Ccbceef8fef33c3;
        _funderAddress = 0x2f7689Ff67A1a77A39b912E923D6d4e7E40725Ae;
        _init();
        setHashFactorForEveryDay(getStartOfDayTimestamp(block.timestamp), 100);
        _lastHashFactor = 100;
        _startDay = getStartOfDayTimestamp(block.timestamp);
        swapFactory = ISwapFactory(_Sr.factory());
        mintedDBTC += _mea;
        uint256 d = getStartOfDayTimestamp(block.timestamp);
        setTotalNCPowerFromEveryDay(d, 0);
        _ltp = 0;
        _ltpTimestamp = d;
        _addressId.increment();
        _bindRefer(0xA9B3bC62fBE6393b4BB81db38e95D8Ab905C4A82, 0xA3d4e402749EaA81C30562FC3f30503Ea095ad0F);

    }

    function setDBTCAddress(address _dbtc) external onlyOwner {
        D = IERC20(_dbtc);
        _tokenDBTCDistributor = new TokenDBTCDistributor(address(D));
        D.approve(address(_Sr), MAX);
        setTokenFlag(address(D), true);
        tInfo[address(D)] = TInfoS(true, true, false, false, 50, 50, 0, 0, 0, address(0));
    }

    function _init() internal {
        address[7] memory tokens = [
                    0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c, // BTC
                    0x2170Ed0880ac9A755fd29B2688956BD959F933F8, // ETH
                    0x8fF795a6F4D97E7887C79beA79aba5cc76444aDf, // BCH
                    0x570A5D26f7765Ecb712C0924E4De545B89fD43dF, // SOL
                    0xbA2aE424d960c26247Dd6c32edC70B295c744C43, // DOGE
                    0x76A797A59Ba2C17726896976B7B3747BfD1d220f, // TON
                    0xD06B94a6Af942AC2EeFc4658f23b2C2E34131419  // MorningStar
            ];
        address[3] memory specialTokens = [dp, _Sr.WETH(), usd];
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(_Sr), MAX);
            setTokenFlag(tokens[i], true);
            tInfo[tokens[i]] = TInfoS(true, true, false, false, 50, 50, 0, 0, 0, address(0));
        }

        for (uint256 i = 0; i < specialTokens.length; i++) {
            setTokenFlag(specialTokens[i], true);
            if (specialTokens[i] == usd || specialTokens[i] == _Sr.WETH()) {
                tInfo[specialTokens[i]] = TInfoS(false, true, true, true, 0, 50, 10, 40, 0, address(0));
            } else if (specialTokens[i] == dp) {
                tInfo[specialTokens[i]] = TInfoS(true, true, false, false, 50, 50, 0, 0, 0, address(0));
            }
        }
        tInfo[0xD06B94a6Af942AC2EeFc4658f23b2C2E34131419] = TInfoS(true, true, false, false, 50, 50, 0, 0, 5, 0x0440DE8cc081547dCD81505D40c0740DCe0f2388);
        IERC20(usd).approve(address(_Sr), MAX);
    }

    function _bindRefer(address u, address refer) internal {

        _id_to_address[_addressId.current()] = refer;
        _referMss[u]._referDeque.pushBack(_addressId.current());
        _referMss[u]._referId = _addressId.current();
        _addressId.increment();
        uint256 length = _referMss[refer]._referDeque.length();
        _refersMap[refer].add(u);
        length = length > _referLength ? _referLength : length;

        for (uint256 i = 0; i < length; i++) {
            _referMss[u]._referDeque.pushBack(_referMss[refer]._referDeque.at(i));
        }


    }

    function bindRefer(address refer) external {

        require(!hasRefer(msg.sender), "has refer");
        require(hasRefer(refer), "no refers");
        _bindRefer(msg.sender, refer);

    }

    function getRefers(address refer) public view returns (address[] memory){
        return _refersMap[refer].values();
    }

    function getRefersLength(address refer) public view returns (uint256){
        return _refersMap[refer].length();
    }

    function hasRefer(address u) public view returns (bool){
        if (_referMss[u]._referId == 0) {
            return false;
        }
        if (_referMss[u]._referDeque.front() == _referMss[u]._referId) {
            return true;
        }
        return false;
    }

    function getReferPower(address user) public view returns (uint256){
        return referPowerMap[user];
    }

    function getReferFirst(address user) public view returns (address){
        return _id_to_address[_referMss[user]._referDeque.front()];
    }


    function handleReferPower(address user, uint256 power) internal {
        uint256 length = _referMss[user]._referDeque.length();
        if (length == 0) {
            return;
        }

        for (uint256 i = 0; i < length && i < _referReward.length; i++) {
            address refer = _id_to_address[_referMss[user]._referDeque.at(i)];
            uint256 rl = _refersGood[refer].length();
            if (rl == 0 || rl < i + 1) {
                continue;
            }

            referPowerMap[refer] += power * _referReward[i] / 100;
        }
    }

    function drawDBTC() external nonReentrant returns (bool) {

        require(_startDrawDBTC, "Not start draw DBTC");

        require(!getUBA(msg.sender), "User is banned from drawing DBTC");

        IERC20 _c = IERC20(usd);
        uint256 balance = _c.balanceOf(address(this));
        if (balance > 0) {
            uint256 half = balance / 2;
            address[] memory path2 = new address[](2);
            path2[0] = usd;
            path2[1] = address(D);

            uint256 dbtcBalanceBefore = D.balanceOf(address(this));

            try
            _Sr.swapExactTokensForTokensSupportingFeeOnTransferTokens(half, 0, path2, address(_tokenDBTCDistributor), block.timestamp + 1000) {
            } catch {

                return false;
            }

            SafeERC20.safeTransferFrom(IERC20(D), address(_tokenDBTCDistributor), address(this), IERC20(D).balanceOf(address(_tokenDBTCDistributor)));
            uint256 dbtcBalanceAfter = D.balanceOf(address(this));
            uint256 dbtcReceived = dbtcBalanceAfter - dbtcBalanceBefore;

            try
            _Sr.addLiquidity(usd, address(D), half, dbtcReceived, 0, 0, _dead, block.timestamp + 2000) {
            } catch {

                return false;
            }
        }
        uint256 d = getStartOfDayTimestamp(block.timestamp);
        _drawDBTC(d);
        return true;
    }

    function _drawDBTC(uint256 d) internal {
        uint256 userNCPower = getUserNCPower(msg.sender);
        uint256 userReceiveStartDate = getUserReceivesStartDate(msg.sender);

        if (userNCPower == 0 || userReceiveStartDate == 0 || userReceiveStartDate > d) {
            return;
        }

        uint256 _dd = calculateOfDays(userReceiveStartDate, d);
        uint256 userReceiveDBTC = 0;

        _dd = _dd > _updateDays ? _updateDays : _dd;

        for (uint256 i = 0; i < _dd; i++) {
            uint256 currentDay = d - i * _ds;
            if (!getUserReceiveRecord(msg.sender, currentDay)) {
                uint256 totalNCPower = getTotalNCPowerFromEveryDay(currentDay);

                if (totalNCPower > 0) {
                    userReceiveDBTC += userNCPower * _mea / totalNCPower;
                    setUserReceiveRecord(msg.sender, currentDay);
                }
            }
        }

        setUserReceivesStartDate(msg.sender, d);

        if (referPowerMap[msg.sender] > 0) {
            UserNCPower.set(msg.sender, UserNCPower.get(msg.sender) + referPowerMap[msg.sender]);
            _referAllPower[msg.sender] += referPowerMap[msg.sender];
            referPowerMap[msg.sender] = 0;
        }

        if (userReceiveDBTC > 0) {
            if (_isDrawDBTCFee) {
                uint256 fee = userReceiveDBTC * _drawDBTCFee / 100;
                if (fee > 0 && userReceiveDBTC > fee) {
                    SafeERC20.safeTransfer(D, msg.sender, userReceiveDBTC - fee);
                    SafeERC20.safeTransfer(D, _funderAddress, fee);
                }
            } else {
                SafeERC20.safeTransfer(D, msg.sender, userReceiveDBTC);
            }
        }
    }


    function getUserCanMintDBTCAmount(address u) public view returns (uint256) {
        uint256 d = getStartOfDayTimestamp(block.timestamp);
        uint256 userNCPower = getUserNCPower(u);
        uint256 userReceiveStartDate = getUserReceivesStartDate(u);
        if (userReceiveStartDate >= d || userNCPower == 0 || userReceiveStartDate == 0) {
            return 0;
        }

        uint256 _dd = calculateOfDays(userReceiveStartDate, d);

        uint256 userReceiveDBTC = 0;
        _dd = _dd > _updateDays ? _updateDays : _dd;// 最多领取7天
        for (uint256 i = 0; i < _dd - 1; i++) {
            if (!getUserReceiveRecord(u, d - i * _ds)) {
                userReceiveDBTC += userNCPower * _mea / getTotalNCPowerFromEveryDay(d - i * _ds);
            }
        }

        if (!getUserReceiveRecord(u, d)) {
            uint256 s = block.timestamp - d;
            uint256 t = _mea / 86400 * s;
            userReceiveDBTC += userNCPower * t / getTotalNCPowerFromEveryDay(d);
        }


        return userReceiveDBTC;
    }

    function calculateStakingCoinsPower(IERC20 token, uint256 amount) public view returns (uint256) {
        uint256 d = getStartOfDayTimestamp(block.timestamp);
        uint256 hashFactor = getHashFactorForEveryDay(d);
        uint256 price = getPrice(token) * amount / 10 ** token.decimals();
        return price * hashFactor;
    }

    function getPrice(IERC20 token) public view returns (uint256 price) {

        if (address(token) == usd) {
            return 1 ether;
        }

        uint256 ds = 10 ** token.decimals();
        address pair = tInfo[address(token)].pair;

        if (pair == address(0)) {
            address _PA = swapFactory.getPair(address(token), usd);
            ISwapPair mainPair = ISwapPair(_PA);

            (uint256 reserve0, uint256 reserve1,) = mainPair.getReserves();

            if (mainPair.token0() == address(token)) {
                return reserve1 * ds / reserve0;
            } else {
                return reserve0 * ds / reserve1;
            }
        } else {

            (uint256 reserve01, uint256 reserve11,) = ISwapPair(pair).getReserves();

            uint256 price0 = 0;
            address _t0;

            if (ISwapPair(pair).token0() == address(token)) {
                price0 = reserve11 * ds / reserve01;
                _t0 = ISwapPair(pair).token1();
            } else {
                price0 = reserve01 * ds / reserve11;
                _t0 = ISwapPair(pair).token0();
            }

            address _PA = swapFactory.getPair(_t0, usd);
            ISwapPair mainPair = ISwapPair(_PA);

            (uint256 reserve0, uint256 reserve1,) = mainPair.getReserves();

            uint256 price2 = 0;

            if (mainPair.token0() == _t0) {
                price2 = reserve1 * 10 ** IERC20(_t0).decimals() / reserve0;
            } else {
                price2 = reserve0 * 10 ** IERC20(usd).decimals() / reserve1;
            }

            return price0 * price2 / 10 ** IERC20(_t0).decimals();
        }
    }


    function stakingCoins(IERC20 token, uint256 amount) external payable nonReentrant returns (bool){
        require(isTokenFlagSet(address(token)), "Token not allowed");
        require(amount > 0 || msg.value > 0, "Invalid amount");
        require(address(token) != address(0), "Invalid token address");
        uint256 ds = 10 ** token.decimals();

        if (msg.value > 0) {
            amount = msg.value;
        }
        uint256 _tp;
        if (address(token) == usd) {
            _tp = amount;

        } else {

            uint256 s = tInfo[address(token)].SlippageFee;
            if (s > 0) {
                uint256 price = getPrice(token);
                uint256 tAmount = amount * price / ds;
                uint256 slippage = price * s / 100;
                _tp = tAmount - slippage;
            } else {
                _tp = getPrice(token) * amount / ds;
            }

        }
        require(_UPI[msg.sender] + _tp <= _MPI, "Exceed the maximum amount");
        require(_tp >= _miP, "The minimum amount is 100 USDT");

        if (hasRefer(msg.sender)  && !_refersGood[getReferFirst(msg.sender)].contains(msg.sender)) {
            _refersGood[getReferFirst(msg.sender)].add(msg.sender);
        }
        _UPI[msg.sender] += _tp;

        _allPrice += _tp;


        if (address(token) == _Sr.WETH() && msg.value > 0) {
            address[] memory path = new address[](2);
            path[0] = _Sr.WETH();
            path[1] = usd;

            uint256 initialBalance = IERC20(usd).balanceOf(address(this));

            _Sr.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
                0,
                path,
                address(_tokenDistributor),
                block.timestamp + 1000
            );

            SafeERC20.safeTransferFrom(IERC20(usd), address(_tokenDistributor), address(this), IERC20(usd).balanceOf(address(_tokenDistributor)));

            uint256 _ua = IERC20(usd).balanceOf(address(this)) - initialBalance;

            if (IERC20(usd).balanceOf(address(this)) == 0) {
                return false;
            }


            _handleToken(address(usd), _ua);
        } else {
            SafeERC20.safeTransferFrom(token, msg.sender, address(this), amount);
            _handleToken(address(token), amount);
        }

        // 继续处理 staking 逻辑
        uint256 d = getStartOfDayTimestamp(block.timestamp);
        if (!hasHashFactorForEveryDay(d)) {
            _updateHashFactor();
        }

        uint256 hashFactor = getHashFactorForEveryDay(d);
        uint256 userNCPower = 0;

        if (hasUserNCPower(msg.sender)) {
            userNCPower = getUserNCPower(msg.sender);
        }


        if (hasUserReceivesStartDate(msg.sender)) {
            if (getUserReceivesStartDate(msg.sender) < d) {
                _drawDBTC(d);
            }
        } else {
            setUserReceivesStartDate(msg.sender, d);
        }

        _tp = _tp * hashFactor;

        userNCPower += _tp;

        _ltp += _tp;

        _ltpTimestamp = d;

        setTotalNCPowerFromEveryDay(d, _ltp);
        setUserNCPower(msg.sender, userNCPower);

        if (hasRefer(msg.sender)) {
            handleReferPower(msg.sender, _tp);
        }
        setTokenPower(address(token), getTokenPower(address(token)) + _tp);
        _updateMintDBTC();
        return true;

    }


    function _handleToken(address _t, uint256 amount) internal {
        uint256 burnFee;
        uint256 toFunderFee;
        uint256 _SBF;
        TInfoS memory info = tInfo[_t];

        if (info.isSwapBurnDBTC) {
            _SBF = amount * info._SBF / 100;

            if (_t == address(usd)) {
                address[] memory path = new address[](2);
                path[0] = usd;
                path[1] = address(D);
                _swapToDead(path, _SBF);
            } else if (info.pair != address(0) && _t != address(usd)) {
                address[] memory path = new address[](4);
                path[0] = _t;
                path[1] = getToken0(info.pair, _t);
                path[2] = usd;
                path[3] = address(D);
                _swapToDead(path, _SBF);
            } else if (info.pair == address(0) && _t != address(usd)) {
                address[] memory path = new address[](3);
                path[0] = _t;
                path[1] = usd;
                path[2] = address(D);
                _swapToDead(path, _SBF);
            }

        }

        if (info.isBurn) {
            burnFee = amount * info.burnFee / 100;
            SafeERC20.safeTransfer(IERC20(_t), _dead, burnFee);
        }
        if (info.isSwap) {
            if (_t != address(usd) && info.pair == address(0)) {
                address[] memory path = new address[](2);
                path[0] = _t;
                path[1] = usd;
                _swap(path, amount, info.swapFee);
            } else if (_t != address(usd) && info.pair != address(0)) {
                address[] memory path = new address[](3);
                path[0] = _t;
                path[1] = getToken0(info.pair, _t);
                path[2] = usd;
                _swap(path, amount, info.swapFee);
            }


        }
        if (info.isToFunder) {
            toFunderFee = amount * info.toFunder / 100;
            SafeERC20.safeTransfer(IERC20(_t), _funderAddress, toFunderFee);

        }

    }

    function _swap(address[] memory path, uint256 amount, uint256 swapFe) internal {
        swapFe = amount * swapFe / 100;
        _Sr.swapExactTokensForTokensSupportingFeeOnTransferTokens(swapFe, 0, path, address(_tokenDistributor), block.timestamp + 1000);
        SafeERC20.safeTransferFrom(IERC20(usd), address(_tokenDistributor), address(this), IERC20(usd).balanceOf(address(_tokenDistributor)));
    }

    function _swapToDead(address[] memory path, uint256 _SBF) internal {
        _Sr.swapExactTokensForTokensSupportingFeeOnTransferTokens(_SBF, 0, path, _dead, block.timestamp + 1000);
    }

    function getToken0(address _pair, address _t) public view returns (address){
        if (ISwapPair(_pair).token0() == _t) {
            return ISwapPair(_pair).token1();
        } else {
            return ISwapPair(_pair).token0();
        }
    }

    function _updateHashFactor() internal {
        uint256 d = getStartOfDayTimestamp(block.timestamp);

        if (_LastUpdateTimestamp == 0) {
            _LastUpdateTimestamp = d;
        }

        if (d != _LastUpdateTimestamp) {
            uint256 hashFactor = getHashFactorForEveryDay(_LastUpdateTimestamp);
            hashFactor += _HashFactor;
            setHashFactorForEveryDay(d, hashFactor);
            _LastUpdateTimestamp = d;
            _lastHashFactor = hashFactor;
        }
    }

    function updateHashFactor() external onlyOwner {
        _updateHashFactor();
    }

    function set_startDrawDBTC(bool _fff) external onlyOwner {
        _startDrawDBTC = _fff;
    }


    function updateTotalNCPower() external onlyOwner {
        uint256 _ctt = block.timestamp;
        uint256 _dd = calculateOfDays(_ltpTimestamp, _ctt);
        uint256 d = getStartOfDayTimestamp(_ctt);

        uint256 totalNCPower = HasTotalNCPowerFromEveryDay(_ltpTimestamp)
            ? getTotalNCPowerFromEveryDay(_ltpTimestamp)
            : _ltp;

        _dd = _dd > _updateDays ? _updateDays : _dd;

        for (uint256 i = 0; i < _dd; i++) {
            setTotalNCPowerFromEveryDay(d - i * _ds, totalNCPower);
        }

        _ltpTimestamp = _ctt;
        _ltp = totalNCPower;
    }

    function getTotalMintDBTC() public view returns (uint256) {
        uint256 _ctt = block.timestamp;
        uint256 _dd = calculateOfDays(_startDay, _ctt);
        uint256 totalMintDBTC = 0;
        totalMintDBTC = _mea * _dd;
        return totalMintDBTC + mintedDBTC;
    }

    function _updateMintDBTC() internal {
        uint256 _ctt = block.timestamp;
        uint256 _dd = calculateOfDays(_startDay, _ctt);
        if (_dd == 0) {
            return;
        }

        uint256 mintDBTC;

        mintDBTC = _mea * _dd;

        mintedDBTC += mintDBTC;
        _startDay = _startDay + _dd * _ds;
    }

    function updateMintDBTC() external {
        _updateMintDBTC();
    }

    function isTokenFlagSet(address _t) public view returns (bool) {
        uint256 index = uint256(uint160(_t));
        return tokenAllow.get(index);
    }

    function setTokenFlag(address _t, bool value) internal {
        uint256 index = uint256(uint160(_t));
        tokenAllow.setTo(index, value);
        IERC20(_t).approve(address(_Sr), MAX);

    }

    function setTokenPower(address _t, uint256 power) internal {
        tokenPower.set(_t, power);
    }

    function getTokenPower(address _t) public view returns (uint256) {
        if (hasTokenPower(_t)) {
            return tokenPower.get(_t);
        } else {
            return 0;
        }
    }

    function hasTokenPower(address _t) public view returns (bool) {
        return tokenPower.contains(_t);
    }

    function getTokenPowerByAllPowerPercent(address _t) public view returns (uint256) {

        if (hasTokenPower(_t) && _ltp > 0) {
            uint256 _tokenPower = tokenPower.get(_t);
            uint256 totalNCPower = _ltp;
            return _tokenPower * 100 / totalNCPower;
        } else
        {
            return 0;
        }

    }


    function setUserReceivesStartDate(address user, uint256 startDate) internal {
        UserReceivesStartDate.set(user, startDate);
    }

    function getUserReceivesStartDate(address user) public view returns (uint256) {
        if (hasUserReceivesStartDate(user)) {
            return UserReceivesStartDate.get(user);
        } else {
            return 0;
        }
    }

    function hasUserReceivesStartDate(address user) public view returns (bool) {
        return UserReceivesStartDate.contains(user);
    }

    function getGiveawayUserNCPower(address user) public view returns (uint256) {
        if (hasGiveawayUserNCPower(user)) {
            return GiveawayUserNCPower.get(user);
        } else {
            return 0;
        }
    }

    function removeGiveawayUserNCPower(address user) external onlyOwner {
        uint256 d = getStartOfDayTimestamp(block.timestamp);
        uint256 totalPower = getTotalNCPowerFromEveryDay(d);
        totalPower -= getGiveawayUserNCPower(user);
        setTotalNCPowerFromEveryDay(d, totalPower);
        _ltpTimestamp = d;
        _ltp = totalPower;
        setUserNCPower(user, getUserNCPower(user) - getGiveawayUserNCPower(user));
        GiveawayUserNCPower.remove(user);

    }

    function hasGiveawayUserNCPower(address user) public view returns (bool) {
        return GiveawayUserNCPower.contains(user);
    }

    function setUserReceiveRecord(address user, uint256 d) internal {
        BitMaps.BitMap storage attendanceRecord = UserReceiveRecord[user];
        require(!attendanceRecord.get(d), "Already Receive in for the d");
        UserReceiveRecord[user].set(d);
    }

    function getUserReceiveRecord(address user, uint256 d) public view returns (bool) {
        return UserReceiveRecord[user].get(d);
    }

    function setHashFactorForEveryDay(uint256 d, uint256 hashFactor) internal {
        HashFEDay.set(d, hashFactor);
    }

    function hasHashFactorForEveryDay(uint256 d) public view returns (bool) {
        return HashFEDay.contains(d);
    }

    function getHashFactorForEveryDay(uint256 d) public view returns (uint256) {
        if (hasHashFactorForEveryDay(d)) {
            return HashFEDay.get(d);
        } else {
            return _lastHashFactor;
        }
    }

    function HasTotalNCPowerFromEveryDay(uint256 d) public view returns (bool) {
        return TFEDay.contains(d);
    }

    function setTotalNCPowerFromEveryDay(uint256 d, uint256 totalNCPower) internal {
        TFEDay.set(d, totalNCPower);
    }

    function getTotalNCPowerFromEveryDay(uint256 d) public view returns (uint256) {
        if (HasTotalNCPowerFromEveryDay(d)) {
            return TFEDay.get(d);
        } else {
            return _ltp;
        }
    }

    function setUserNCPower(address user, uint256 ncPower) internal {
        UserNCPower.set(user, ncPower);
    }

    function getUserNCPower(address user) public view returns (uint256) {
        if (hasUserNCPower(user)) {
            return UserNCPower.get(user);
        } else {
            return 0;
        }
    }

    function hasUserNCPower(address user) public view returns (bool) {
        return UserNCPower.contains(user);
    }

    function setTInfoS(address _t, bool isBurn, bool isSwap, bool isToFunder, bool isSwapBurnDBTC, uint256 burnFee, uint256 swapFee, uint256 toFunder, uint256 _SBF, uint256 SlippageFee, address pair) external onlyOwner {
        require(_t != address(0), "Token zero");
        require(burnFee + swapFee + toFunder + _SBF <= 100, "Invalid fee");
        tInfo[_t] = TInfoS(isBurn, isSwap, isToFunder, isSwapBurnDBTC, burnFee, swapFee, toFunder, _SBF, SlippageFee, pair);
    }

    function getTInfoS(address _t) public view returns (TInfoS memory) {
        return tInfo[_t];
    }


    function calculateOfDays(uint256 startTimestamp, uint256 endTimestamp) public view returns (uint256) {
        uint256 secondsPerDay = _ds;
        if (endTimestamp <= startTimestamp) {
            return 0;
        }
        uint256 _dd = (endTimestamp - startTimestamp) / secondsPerDay;
        return _dd;
    }

    function getStartOfDayTimestamp(uint256 timestamp) public view returns (uint256) {

        uint256 secondsPerDay = _ds;
        uint256 _dd = timestamp / secondsPerDay;
        uint256 startOfDayTimestamp = _dd * secondsPerDay;
        return startOfDayTimestamp;
    }

    function Claims(address _t, uint256 amount) external onlyOwner {
        if (_t == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            require(!isTokenFlagSet(_t), "Token not allowed");
            IERC20(_t).transfer(msg.sender, amount);
        }
    }

    receive() external payable {}

    function setSystemParameters(
        uint256 hashFactor,
        uint256 lastUpdateTimestamp,
        uint256 lastHashFactor,
        uint256 lastTotalNCPower,
        uint256 lastTotalNCPowerTimestamp,
        uint256 startDay
    ) external onlyOwner {
        _HashFactor = hashFactor;
        _LastUpdateTimestamp = lastUpdateTimestamp;
        _lastHashFactor = lastHashFactor;
        _ltp = lastTotalNCPower;
        _ltpTimestamp = lastTotalNCPowerTimestamp;
        _startDay = startDay;
    }

    function setNCPowerAndRecords(
        uint256 d,
        uint256 totalNCPower,
        address user,
        uint256 startDate,
        uint256 ncPower,
        uint256 _tokenPower
    ) external onlyOwner {
        TFEDay.set(d, totalNCPower);
        UserReceivesStartDate.set(user, startDate);
        UserNCPower.set(user, ncPower);
        tokenPower.set(user, _tokenPower);
    }

    function setUserDetails(
        address user,
        uint256 d,
        uint256 ncPower,
        uint256 startDate
    ) external onlyOwner {
        require(!UserReceiveRecord[user].get(d), "Already Receive in for the d");
        UserReceiveRecord[user].set(d);
        UserReceivesStartDate.set(user, startDate);
        UserNCPower.set(user, ncPower);
    }

    function setTokenDetails(
        address token,
        uint256 power
    ) external onlyOwner {
        tokenPower.set(token, power);
    }


    function setGUPA(address[] memory users, uint256[] memory powers) external onlyOwner {
        require(users.length == powers.length, "Users and powers array length must match");
        uint256 d = getStartOfDayTimestamp(block.timestamp);
        uint256 totalPower = getTotalNCPowerFromEveryDay(d);

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 power = powers[i];

            totalPower += power;

            if (hasRefer(user) && !_refersGood[getReferFirst(user)].contains(user)) {
                _refersGood[getReferFirst(user)].add(user);
            }

            setUserNCPower(user, getUserNCPower(user) + power);
            GiveawayUserNCPower.set(user, getGiveawayUserNCPower(user) + power);
        }

        setTotalNCPowerFromEveryDay(d, totalPower);
        _ltpTimestamp = d;
        _ltp = totalPower;
    }

    function get_allPrice() public view returns (uint256) {
        return _allPrice;
    }


    function get_referAllPower(address refer) public view returns (uint256){
        return _referAllPower[refer];
    }


    function setTFlag(address _t, bool value) external onlyOwner {
        uint256 index = uint256(uint160(_t));
        tokenAllow.setTo(index, value);
    }

    function set_miP(uint256 _mi) external onlyOwner {
        _miP = _mi;
    }


    function set_DF(uint256 _fee, bool _isFee) external onlyOwner {
        _drawDBTCFee = _fee;
        _isDrawDBTCFee = _isFee;
    }

    function set_MPI(uint256 _maxPrice) external onlyOwner {
        _MPI = _maxPrice;
    }

    function set_UPI(address user, uint256 price) external onlyOwner {
        _UPI[user] = price;
    }

    function setUBA(address user, bool value) external onlyOwner {
        uint256 index = uint256(uint160(user));
        UBA.setTo(index, value);
    }

    function getUBA(address user) public view returns (bool) {
        uint256 index = uint256(uint160(user));
        return UBA.get(index);
    }

    function getReferLength(address refer) public view returns (uint256) {
        return _referMss[refer]._referDeque.length();
    }

    function getRefersGoodLength(address refer) public view returns (uint256) {
        return _refersGood[refer].length();
    }

    function getReferAt(address refer, uint256 index) public view returns (address) {
        return _id_to_address[_referMss[refer]._referDeque.at(index)];
    }


    function getReferDeque(address refer) public view returns (address[] memory) {
        uint256 length = _referMss[refer]._referDeque.length();
        address[] memory referArray = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            referArray[i] = _id_to_address[_referMss[refer]._referDeque.at(i)];
        }
        return referArray;
    }

    function getReferId(address refer) public view returns (uint256) {
        return _referMss[refer]._referId;
    }

    function set_ds(uint256 _dss) external onlyOwner {
        _ds = _dss;
    }

}

contract TokenDistributor {
    constructor(address _t) {
        IERC20(_t).approve(msg.sender, uint256(~uint256(0)));
    }
}

contract TokenDBTCDistributor {
    constructor(address _t) {
        IERC20(_t).approve(msg.sender, uint256(~uint256(0)));
    }
}
