// Currency conversion utilities

// Exchange rates (in production, fetch from API)
const EXCHANGE_RATES = {
  DZD_TO_EUR: 0.0074, // 1 DZD = 0.0074 EUR (approximate)
  EUR_TO_DZD: 135.14, // 1 EUR = 135.14 DZD (approximate)
  DZD_TO_USD: 0.0075, // 1 DZD = 0.0075 USD (approximate)
  USD_TO_DZD: 133.33, // 1 USD = 133.33 DZD (approximate)
  DZD_TO_GBP: 0.0059, // 1 DZD = 0.0059 GBP (approximate)
  GBP_TO_DZD: 169.49, // 1 GBP = 169.49 DZD (approximate)
  EUR_TO_USD: 1.08, // 1 EUR = 1.08 USD (approximate)
  USD_TO_EUR: 0.93, // 1 USD = 0.93 EUR (approximate)
  EUR_TO_GBP: 0.85, // 1 EUR = 0.85 GBP (approximate)
  GBP_TO_EUR: 1.18, // 1 GBP = 1.18 EUR (approximate)
  USD_TO_GBP: 0.79, // 1 USD = 0.79 GBP (approximate)
  GBP_TO_USD: 1.27, // 1 GBP = 1.27 USD (approximate)
};

export interface ConversionResult {
  fromAmount: number;
  toAmount: number;
  fromCurrency: string;
  toCurrency: string;
  rate: number;
  timestamp: Date;
}

// Convert DZD to EUR
export const convertDzdToEur = (dzdAmount: number): ConversionResult => {
  const eurAmount = dzdAmount * EXCHANGE_RATES.DZD_TO_EUR;
  return {
    fromAmount: dzdAmount,
    toAmount: parseFloat(eurAmount.toFixed(2)),
    fromCurrency: "DZD",
    toCurrency: "EUR",
    rate: EXCHANGE_RATES.DZD_TO_EUR,
    timestamp: new Date(),
  };
};

// Convert EUR to DZD
export const convertEurToDzd = (eurAmount: number): ConversionResult => {
  const dzdAmount = eurAmount * EXCHANGE_RATES.EUR_TO_DZD;
  return {
    fromAmount: eurAmount,
    toAmount: parseFloat(dzdAmount.toFixed(2)),
    fromCurrency: "EUR",
    toCurrency: "DZD",
    rate: EXCHANGE_RATES.EUR_TO_DZD,
    timestamp: new Date(),
  };
};

// Convert DZD to USD
export const convertDzdToUsd = (dzdAmount: number): ConversionResult => {
  const usdAmount = dzdAmount * EXCHANGE_RATES.DZD_TO_USD;
  return {
    fromAmount: dzdAmount,
    toAmount: parseFloat(usdAmount.toFixed(2)),
    fromCurrency: "DZD",
    toCurrency: "USD",
    rate: EXCHANGE_RATES.DZD_TO_USD,
    timestamp: new Date(),
  };
};

// Convert USD to DZD
export const convertUsdToDzd = (usdAmount: number): ConversionResult => {
  const dzdAmount = usdAmount * EXCHANGE_RATES.USD_TO_DZD;
  return {
    fromAmount: usdAmount,
    toAmount: parseFloat(dzdAmount.toFixed(2)),
    fromCurrency: "USD",
    toCurrency: "DZD",
    rate: EXCHANGE_RATES.USD_TO_DZD,
    timestamp: new Date(),
  };
};

// Convert DZD to GBP
export const convertDzdToGbp = (dzdAmount: number): ConversionResult => {
  const gbpAmount = dzdAmount * EXCHANGE_RATES.DZD_TO_GBP;
  return {
    fromAmount: dzdAmount,
    toAmount: parseFloat(gbpAmount.toFixed(2)),
    fromCurrency: "DZD",
    toCurrency: "GBP",
    rate: EXCHANGE_RATES.DZD_TO_GBP,
    timestamp: new Date(),
  };
};

// Convert GBP to DZD
export const convertGbpToDzd = (gbpAmount: number): ConversionResult => {
  const dzdAmount = gbpAmount * EXCHANGE_RATES.GBP_TO_DZD;
  return {
    fromAmount: gbpAmount,
    toAmount: parseFloat(dzdAmount.toFixed(2)),
    fromCurrency: "GBP",
    toCurrency: "DZD",
    rate: EXCHANGE_RATES.GBP_TO_DZD,
    timestamp: new Date(),
  };
};

// Convert EUR to USD
export const convertEurToUsd = (eurAmount: number): ConversionResult => {
  const usdAmount = eurAmount * EXCHANGE_RATES.EUR_TO_USD;
  return {
    fromAmount: eurAmount,
    toAmount: parseFloat(usdAmount.toFixed(2)),
    fromCurrency: "EUR",
    toCurrency: "USD",
    rate: EXCHANGE_RATES.EUR_TO_USD,
    timestamp: new Date(),
  };
};

// Convert USD to EUR
export const convertUsdToEur = (usdAmount: number): ConversionResult => {
  const eurAmount = usdAmount * EXCHANGE_RATES.USD_TO_EUR;
  return {
    fromAmount: usdAmount,
    toAmount: parseFloat(eurAmount.toFixed(2)),
    fromCurrency: "USD",
    toCurrency: "EUR",
    rate: EXCHANGE_RATES.USD_TO_EUR,
    timestamp: new Date(),
  };
};

// Convert EUR to GBP
export const convertEurToGbp = (eurAmount: number): ConversionResult => {
  const gbpAmount = eurAmount * EXCHANGE_RATES.EUR_TO_GBP;
  return {
    fromAmount: eurAmount,
    toAmount: parseFloat(gbpAmount.toFixed(2)),
    fromCurrency: "EUR",
    toCurrency: "GBP",
    rate: EXCHANGE_RATES.EUR_TO_GBP,
    timestamp: new Date(),
  };
};

// Convert GBP to EUR
export const convertGbpToEur = (gbpAmount: number): ConversionResult => {
  const eurAmount = gbpAmount * EXCHANGE_RATES.GBP_TO_EUR;
  return {
    fromAmount: gbpAmount,
    toAmount: parseFloat(eurAmount.toFixed(2)),
    fromCurrency: "GBP",
    toCurrency: "EUR",
    rate: EXCHANGE_RATES.GBP_TO_EUR,
    timestamp: new Date(),
  };
};

// Convert USD to GBP
export const convertUsdToGbp = (usdAmount: number): ConversionResult => {
  const gbpAmount = usdAmount * EXCHANGE_RATES.USD_TO_GBP;
  return {
    fromAmount: usdAmount,
    toAmount: parseFloat(gbpAmount.toFixed(2)),
    fromCurrency: "USD",
    toCurrency: "GBP",
    rate: EXCHANGE_RATES.USD_TO_GBP,
    timestamp: new Date(),
  };
};

// Convert GBP to USD
export const convertGbpToUsd = (gbpAmount: number): ConversionResult => {
  const usdAmount = gbpAmount * EXCHANGE_RATES.GBP_TO_USD;
  return {
    fromAmount: gbpAmount,
    toAmount: parseFloat(usdAmount.toFixed(2)),
    fromCurrency: "GBP",
    toCurrency: "USD",
    rate: EXCHANGE_RATES.GBP_TO_USD,
    timestamp: new Date(),
  };
};

// Universal conversion function
export const convertCurrency = (
  amount: number,
  fromCurrency: string,
  toCurrency: string,
): ConversionResult => {
  if (fromCurrency === toCurrency) {
    return {
      fromAmount: amount,
      toAmount: amount,
      fromCurrency,
      toCurrency,
      rate: 1,
      timestamp: new Date(),
    };
  }

  const conversionKey =
    `${fromCurrency}_TO_${toCurrency}` as keyof typeof EXCHANGE_RATES;
  const rate = EXCHANGE_RATES[conversionKey];

  if (!rate) {
    throw new Error(
      `Conversion from ${fromCurrency} to ${toCurrency} is not supported`,
    );
  }

  const convertedAmount = amount * rate;
  return {
    fromAmount: amount,
    toAmount: parseFloat(convertedAmount.toFixed(2)),
    fromCurrency,
    toCurrency,
    rate,
    timestamp: new Date(),
  };
};

// Get current exchange rate
export const getExchangeRate = (from: string, to: string): number => {
  const key = `${from}_TO_${to}` as keyof typeof EXCHANGE_RATES;
  return EXCHANGE_RATES[key] || 0;
};

// Format currency for display
export const formatCurrency = (amount: number, currency: string): string => {
  // Ensure amount is a valid number
  const numericAmount =
    typeof amount === "number" && !isNaN(amount) ? amount : 0;

  switch (currency) {
    case "DZD":
      return `${numericAmount.toLocaleString()} دج`;
    case "EUR":
      return `€${numericAmount.toFixed(2)}`;
    case "USD":
      return `$${numericAmount.toFixed(2)}`;
    case "GBP":
      return `£${numericAmount.toFixed(2)}`;
    default:
      return numericAmount.toString();
  }
};
