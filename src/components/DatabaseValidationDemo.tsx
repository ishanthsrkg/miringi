import React, { useState } from "react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { Label } from "./ui/label";
import { Alert, AlertDescription } from "./ui/alert";
import { CheckCircle, XCircle, AlertTriangle } from "lucide-react";
import {
  validateAmount,
  validateCurrency,
  validateTransactionType,
  validateInvestmentType,
  validateProfitRate,
  validateDateRange,
  validateAccountNumber,
  validatePhoneNumber,
  validateEmail,
  validatePassword,
  validateTransactionData,
  validateInvestmentData,
} from "../utils/validation";

interface ValidationResult {
  isValid: boolean;
  value?: any;
  error?: string;
  errors?: string[];
}

function DatabaseValidationDemo() {
  const [testValues, setTestValues] = useState({
    amount: "",
    currency: "",
    transactionType: "",
    investmentType: "",
    profitRate: "",
    startDate: "",
    endDate: "",
    accountNumber: "",
    phoneNumber: "",
    email: "",
    password: "",
  });

  const [results, setResults] = useState<Record<string, ValidationResult>>({});

  const handleValidation = (field: string, value: string) => {
    let result: ValidationResult;

    switch (field) {
      case "amount":
        result = validateAmount(value);
        break;
      case "currency":
        result = validateCurrency(value);
        break;
      case "transactionType":
        result = validateTransactionType(value);
        break;
      case "investmentType":
        result = validateInvestmentType(value);
        break;
      case "profitRate":
        result = validateProfitRate(value);
        break;
      case "accountNumber":
        result = validateAccountNumber(value);
        break;
      case "phoneNumber":
        result = validatePhoneNumber(value);
        break;
      case "email":
        result = validateEmail(value);
        break;
      case "password":
        result = validatePassword(value);
        break;
      default:
        result = { isValid: true };
    }

    setResults((prev) => ({ ...prev, [field]: result }));
  };

  const handleDateRangeValidation = () => {
    const result = validateDateRange(testValues.startDate, testValues.endDate);
    setResults((prev) => ({ ...prev, dateRange: result }));
  };

  const handleComplexValidation = (type: "transaction" | "investment") => {
    let result: ValidationResult;

    if (type === "transaction") {
      const transactionData = {
        amount: testValues.amount,
        currency: testValues.currency,
        type: testValues.transactionType,
        description: "معاملة تجريبية",
      };
      result = validateTransactionData(transactionData);
    } else {
      const investmentData = {
        amount: testValues.amount,
        type: testValues.investmentType,
        profit_rate: testValues.profitRate,
        start_date: testValues.startDate,
        end_date: testValues.endDate,
      };
      result = validateInvestmentData(investmentData);
    }

    setResults((prev) => ({ ...prev, [type]: result }));
  };

  const renderValidationResult = (field: string) => {
    const result = results[field];
    if (!result) return null;

    return (
      <div className="mt-2">
        {result.isValid ? (
          <div className="flex items-center text-green-600 text-sm">
            <CheckCircle className="w-4 h-4 mr-2" />
            صحيح
            {result.value !== undefined && (
              <span className="mr-2 font-mono bg-green-100 px-2 py-1 rounded">
                {typeof result.value === "object"
                  ? JSON.stringify(result.value)
                  : result.value}
              </span>
            )}
          </div>
        ) : (
          <div className="flex items-start text-red-600 text-sm">
            <XCircle className="w-4 h-4 mr-2 mt-0.5" />
            <div>
              {result.error && <div>{result.error}</div>}
              {result.errors && (
                <ul className="list-disc list-inside">
                  {result.errors.map((error, index) => (
                    <li key={index}>{error}</li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 p-4">
      <div className="max-w-4xl mx-auto">
        <Card className="bg-white/10 backdrop-blur-md border border-white/20 text-white">
          <CardHeader>
            <CardTitle className="text-2xl font-bold text-center">
              صفحة اختبار التحقق من صحة البيانات
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <Alert className="bg-blue-500/20 border-blue-400/30">
              <AlertTriangle className="h-4 w-4" />
              <AlertDescription className="text-blue-200">
                هذه الصفحة لاختبار دوال التحقق من صحة البيانات في قاعدة البيانات
              </AlertDescription>
            </Alert>

            {/* اختبار المبالغ */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <Label htmlFor="amount">اختبار المبلغ</Label>
                <Input
                  id="amount"
                  type="number"
                  placeholder="أدخل مبلغاً"
                  value={testValues.amount}
                  onChange={(e) => {
                    setTestValues((prev) => ({
                      ...prev,
                      amount: e.target.value,
                    }));
                    handleValidation("amount", e.target.value);
                  }}
                  className="bg-white/10 border-white/30 text-white"
                />
                {renderValidationResult("amount")}
              </div>

              <div>
                <Label htmlFor="currency">اختبار العملة</Label>
                <Input
                  id="currency"
                  placeholder="dzd, eur, usd, gbp"
                  value={testValues.currency}
                  onChange={(e) => {
                    setTestValues((prev) => ({
                      ...prev,
                      currency: e.target.value,
                    }));
                    handleValidation("currency", e.target.value);
                  }}
                  className="bg-white/10 border-white/30 text-white"
                />
                {renderValidationResult("currency")}
              </div>

              <div>
                <Label htmlFor="transactionType">نوع المعاملة</Label>
                <Input
                  id="transactionType"
                  placeholder="recharge, transfer, bill, etc."
                  value={testValues.transactionType}
                  onChange={(e) => {
                    setTestValues((prev) => ({
                      ...prev,
                      transactionType: e.target.value,
                    }));
                    handleValidation("transactionType", e.target.value);
                  }}
                  className="bg-white/10 border-white/30 text-white"
                />
                {renderValidationResult("transactionType")}
              </div>

              <div>
                <Label htmlFor="investmentType">نوع الاستثمار</Label>
                <Input
                  id="investmentType"
                  placeholder="weekly, monthly, quarterly, yearly"
                  value={testValues.investmentType}
                  onChange={(e) => {
                    setTestValues((prev) => ({
                      ...prev,
                      investmentType: e.target.value,
                    }));
                    handleValidation("investmentType", e.target.value);
                  }}
                  className="bg-white/10 border-white/30 text-white"
                />
                {renderValidationResult("investmentType")}
              </div>

              <div>
                <Label htmlFor="profitRate">معدل الربح (%)</Label>
                <Input
                  id="profitRate"
                  type="number"
                  placeholder="0-100"
                  value={testValues.profitRate}
                  onChange={(e) => {
                    setTestValues((prev) => ({
                      ...prev,
                      profitRate: e.target.value,
                    }));
                    handleValidation("profitRate", e.target.value);
                  }}
                  className="bg-white/10 border-white/30 text-white"
                />
                {renderValidationResult("profitRate")}
              </div>

              <div>
                <Label htmlFor="accountNumber">رقم الحساب</Label>
                <Input
                  id="accountNumber"
                  placeholder="ACC123456789"
                  value={testValues.accountNumber}
                  onChange={(e) => {
                    setTestValues((prev) => ({
                      ...prev,
                      accountNumber: e.target.value,
                    }));
                    handleValidation("accountNumber", e.target.value);
                  }}
                  className="bg-white/10 border-white/30 text-white"
                />
                {renderValidationResult("accountNumber")}
              </div>

              <div>
                <Label htmlFor="phoneNumber">رقم الهاتف</Label>
                <Input
                  id="phoneNumber"
                  placeholder="+966501234567"
                  value={testValues.phoneNumber}
                  onChange={(e) => {
                    setTestValues((prev) => ({
                      ...prev,
                      phoneNumber: e.target.value,
                    }));
                    handleValidation("phoneNumber", e.target.value);
                  }}
                  className="bg-white/10 border-white/30 text-white"
                />
                {renderValidationResult("phoneNumber")}
              </div>

              <div>
                <Label htmlFor="email">البريد الإلكتروني</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="user@example.com"
                  value={testValues.email}
                  onChange={(e) => {
                    setTestValues((prev) => ({
                      ...prev,
                      email: e.target.value,
                    }));
                    handleValidation("email", e.target.value);
                  }}
                  className="bg-white/10 border-white/30 text-white"
                />
                {renderValidationResult("email")}
              </div>

              <div>
                <Label htmlFor="password">كلمة المرور</Label>
                <Input
                  id="password"
                  type="password"
                  placeholder="كلمة المرور"
                  value={testValues.password}
                  onChange={(e) => {
                    setTestValues((prev) => ({
                      ...prev,
                      password: e.target.value,
                    }));
                    handleValidation("password", e.target.value);
                  }}
                  className="bg-white/10 border-white/30 text-white"
                />
                {renderValidationResult("password")}
              </div>
            </div>

            {/* اختبار التواريخ */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">اختبار نطاق التواريخ</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="startDate">تاريخ البداية</Label>
                  <Input
                    id="startDate"
                    type="datetime-local"
                    value={testValues.startDate}
                    onChange={(e) => {
                      setTestValues((prev) => ({
                        ...prev,
                        startDate: e.target.value,
                      }));
                    }}
                    className="bg-white/10 border-white/30 text-white"
                  />
                </div>
                <div>
                  <Label htmlFor="endDate">تاريخ النهاية</Label>
                  <Input
                    id="endDate"
                    type="datetime-local"
                    value={testValues.endDate}
                    onChange={(e) => {
                      setTestValues((prev) => ({
                        ...prev,
                        endDate: e.target.value,
                      }));
                    }}
                    className="bg-white/10 border-white/30 text-white"
                  />
                </div>
              </div>
              <Button
                onClick={handleDateRangeValidation}
                className="bg-blue-600 hover:bg-blue-700"
              >
                اختبار نطاق التواريخ
              </Button>
              {renderValidationResult("dateRange")}
            </div>

            {/* اختبار التحقق المعقد */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">اختبار التحقق المعقد</h3>
              <div className="flex gap-4">
                <Button
                  onClick={() => handleComplexValidation("transaction")}
                  className="bg-green-600 hover:bg-green-700"
                >
                  اختبار بيانات المعاملة
                </Button>
                <Button
                  onClick={() => handleComplexValidation("investment")}
                  className="bg-purple-600 hover:bg-purple-700"
                >
                  اختبار بيانات الاستثمار
                </Button>
              </div>
              {renderValidationResult("transaction")}
              {renderValidationResult("investment")}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

export default DatabaseValidationDemo;
