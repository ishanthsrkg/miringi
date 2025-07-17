import { useState, useCallback, useMemo } from "react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "./ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";
import { ArrowRightLeft, Calculator, TrendingUp } from "lucide-react";
import {
  convertCurrency,
  formatCurrency,
  ConversionResult,
} from "../utils/currency";

interface CurrencyConverterProps {
  isOpen: boolean;
  onClose: () => void;
  onConvert: (result: ConversionResult) => void;
}

export default function CurrencyConverter({
  isOpen,
  onClose,
  onConvert,
}: CurrencyConverterProps) {
  const [amount, setAmount] = useState("");
  const [fromCurrency, setFromCurrency] = useState("DZD");
  const [toCurrency, setToCurrency] = useState("EUR");
  const [result, setResult] = useState<ConversionResult | null>(null);
  const [error, setError] = useState("");

  const handleConvert = useCallback(() => {
    if (!amount || parseFloat(amount) <= 0) {
      setError("يرجى إدخال مبلغ صحيح");
      return;
    }

    if (fromCurrency === toCurrency) {
      setError("يرجى اختيار عملات مختلفة للتحويل");
      return;
    }

    setError("");
    const amountNum = parseFloat(amount);

    try {
      const conversionResult = convertCurrency(
        amountNum,
        fromCurrency,
        toCurrency,
      );
      setResult(conversionResult);
    } catch (error) {
      setError("تحويل غير مدعوم حالياً");
    }
  }, [amount, fromCurrency, toCurrency]);

  const handleConfirmConversion = useCallback(() => {
    if (result) {
      onConvert(result);
      onClose();
      setAmount("");
      setResult(null);
    }
  }, [result, onConvert, onClose]);

  const swapCurrencies = useCallback(() => {
    setFromCurrency(toCurrency);
    setToCurrency(fromCurrency);
    setResult(null);
  }, [fromCurrency, toCurrency]);

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="bg-gradient-to-br from-slate-900/95 via-purple-900/95 to-slate-900/95 backdrop-blur-md border border-white/20 text-white max-w-md mx-auto">
        <DialogHeader className="text-center">
          <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
            <Calculator className="w-6 h-6 text-purple-400" />
            <span>محول العملات</span>
          </DialogTitle>
          <DialogDescription className="text-gray-300">
            تحويل بين الدينار الجزائري، اليورو، الدولار الأمريكي والجنيه
            الإسترليني
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-6 mt-6">
          {/* Amount Input */}
          <div className="space-y-2">
            <Label htmlFor="amount" className="text-white font-medium">
              المبلغ
            </Label>
            <Input
              id="amount"
              type="number"
              placeholder="أدخل المبلغ"
              value={amount}
              onChange={(e) => {
                setAmount(e.target.value);
                setError("");
                setResult(null);
              }}
              className="text-center text-lg bg-white/10 border-white/30 text-white placeholder:text-gray-400 h-12"
            />
          </div>

          {/* Currency Selection */}
          <div className="grid grid-cols-2 gap-4 items-end">
            <div className="space-y-2">
              <Label className="text-white font-medium">من</Label>
              <Select value={fromCurrency} onValueChange={setFromCurrency}>
                <SelectTrigger className="bg-white/10 border-white/30 text-white">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="DZD">دينار جزائري (DZD)</SelectItem>
                  <SelectItem value="EUR">يورو (EUR)</SelectItem>
                  <SelectItem value="USD">دولار أمريكي (USD)</SelectItem>
                  <SelectItem value="GBP">جنيه إسترليني (GBP)</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="flex justify-center pb-2">
              <Button
                onClick={swapCurrencies}
                variant="ghost"
                size="icon"
                className="text-white hover:bg-white/10 rounded-full"
              >
                <ArrowRightLeft className="w-4 h-4" />
              </Button>
            </div>

            <div className="space-y-2">
              <Label className="text-white font-medium">إلى</Label>
              <Select value={toCurrency} onValueChange={setToCurrency}>
                <SelectTrigger className="bg-white/10 border-white/30 text-white">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="DZD">دينار جزائري (DZD)</SelectItem>
                  <SelectItem value="EUR">يورو (EUR)</SelectItem>
                  <SelectItem value="USD">دولار أمريكي (USD)</SelectItem>
                  <SelectItem value="GBP">جنيه إسترليني (GBP)</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          {error && (
            <div className="bg-red-500/20 border border-red-400/30 rounded-lg p-3 text-red-200 text-center">
              {error}
            </div>
          )}

          {/* Conversion Result */}
          {result && (
            <Card className="bg-gradient-to-r from-green-500/20 to-blue-500/20 border border-green-400/30 backdrop-blur-sm">
              <CardContent className="p-4">
                <div className="text-center space-y-3">
                  <div className="flex items-center justify-center gap-3">
                    <div className="text-center">
                      <p className="text-white font-bold text-lg">
                        {formatCurrency(result.fromAmount, result.fromCurrency)}
                      </p>
                      <p className="text-gray-300 text-xs">
                        {result.fromCurrency}
                      </p>
                    </div>
                    <TrendingUp className="w-5 h-5 text-green-400" />
                    <div className="text-center">
                      <p className="text-green-300 font-bold text-lg">
                        {formatCurrency(result.toAmount, result.toCurrency)}
                      </p>
                      <p className="text-gray-300 text-xs">
                        {result.toCurrency}
                      </p>
                    </div>
                  </div>
                  <p className="text-xs text-blue-200">
                    سعر الصرف: 1 {result.fromCurrency} ={" "}
                    {result.rate.toFixed(4)} {result.toCurrency}
                  </p>
                </div>
              </CardContent>
            </Card>
          )}

          {/* Action Buttons */}
          <div className="flex gap-3">
            <Button
              onClick={handleConvert}
              className="flex-1 h-12 bg-gradient-to-r from-purple-500 to-blue-600 hover:from-purple-600 hover:to-blue-700"
            >
              تحويل
            </Button>
            {result && (
              <Button
                onClick={handleConfirmConversion}
                className="flex-1 h-12 bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700"
              >
                تأكيد التحويل
              </Button>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
