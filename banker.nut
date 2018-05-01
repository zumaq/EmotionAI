class Banker
{

}

/**
 * Loans the given amount of money from the bank.
 * @param money The amount to loan.
 * @return True if the loaning succeeded.
 */
function Banker::GetMoney(money)
{
	local toloan = AICompany.GetLoanAmount() + money;
	if (AICompany.SetMinimumLoanAmount(toloan)) return true;
	else return false;
}

/**
 * Calculates how much cash will be on hand if the maximum loan is taken.
 * @return The maximum amount of money.
 */
function Banker::GetMaxBankBalance()
{
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local maxbalance = balance + AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount();
	// overflow protection by krinn
	return (maxbalance >= balance) ? maxbalance : balance;
}

/**
 * Adjusts the loan so that the company will have at least the given amount of money.
 * @param money The minimum amount of money to have.
 * @return True if the action succeeded.
 */
function Banker::SetMinimumBankBalance(money)
{
	local needed = money - AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	if (needed < 0) return true;
	else {
		if (Banker.GetMoney(needed)) return true;
		else return false;
	}
}

/**
 * Pays back loan if possible, but tries to have at least the loan interval (10,000 pounds)
 * @return True if the action succeeded.
 */
function Banker::PayLoan()
{
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	// overflow protection by krinn
	if (balance + 1 < balance) {
		if (AICompany.SetMinimumLoanAmount(0)) return true;
		else return false;
	}
	local money = 0 - (balance - AICompany.GetLoanAmount()) + Banker.GetMinimumCashNeeded();
	if (money > 0) {
		if (AICompany.SetMinimumLoanAmount(money)) return true;
		else return false;
	} else {
		if (AICompany.SetMinimumLoanAmount(0)) return true;
		else return false;
	}
}

/**
 * Calculates the percentage of inflation since the start of the game.
 * @return The percentage by which prices have risen since the start of the game.
 * It is 1.0 if there is no inflation, 2.0 if prices have doubled, etc.
 */
function Banker::GetInflationRate()
{
	return AICompany.GetMaxLoanAmount().tofloat() / AIGameSettings.GetValue("difficulty.max_loan").tofloat();
}

/**
 * Determines how much money the company needs to build a new route,
 * based on the current amount of routes.
 * @param routecount The current amount of routes.
 * @return The minimum amount of money to build a new route.
 */
function Banker::MinimumMoneyToBuild(routecount)
{
	if ((routecount >= 5) || !use_roadvehs) {
		// Basically it's 40,000 plus the price of the engine needed.
		local passengers = EmotionAI.GetPassengersCargo();
		local wagon = cBuilder.ChooseWagon(passengers, null);
		local price = 0;
		if (wagon != null) {
			local engine = cBuilder.ChooseTrainEngine(passengers, 130, wagon, 5, null);
			if (engine != null) {
				price = Banker.InflatedValue(40000) + AIEngine.GetPrice(engine);
			}
		}
		local minplaneprice = Banker.MinimumMoneyToUseAircraft();
		if (use_aircraft && minplaneprice > price) price = minplaneprice;
		if (price > Banker.InflatedValue(90000)) return price;
	}
	// 90,000 is needed at the start of the game
	return Banker.InflatedValue(90000);

}

/**
 * Calculates how much money is needed to build plane routes.
 * @return The minimum amount of money.
 */
function Banker::MinimumMoneyToUseAircraft()
{
	local cheapest = cBuilder.ChoosePlane(EmotionAI.GetPassengersCargo(), false, 16384, true);
	if (cheapest == null) return -1;
	local price = AIEngine.GetPrice(cheapest);
	return Banker.InflatedValue(40000) + price;
}

/**
 * Calculates the minimum amount of cash needed to be at hand. This is used to
 * avoid going bankrupt because of station maintenance costs.
 * @return 10000 pounds plus the expected station maintenance costs.
 */
function Banker::GetMinimumCashNeeded()
{
	local stationlist = AIStationList(AIStation.STATION_ANY);
	local maintenance = Banker.InflatedValue(stationlist.Count() * 50);
	return maintenance + AICompany.GetLoanInterval();
}

/**
 * Multiplies a given amount by the inflation rate and returns the new value.
 * @param amount The amount of money to multiply.
 * @return The inflated value of the given amount.
 */
function Banker::InflatedValue(amount)
{
  return (amount * Banker.GetInflationRate()).tointeger();
}
