import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useAuth } from "../hooks/useAuth";
import { supabase } from "../lib/supabase";
import { RefreshCw, User, Database, Settings, AlertCircle } from "lucide-react";
import { Alert, AlertDescription } from "@/components/ui/alert";

export default function DebugAuth() {
  const { user, loading, error } = useAuth();
  const [sessionInfo, setSessionInfo] = useState<any>(null);
  const [connectionTest, setConnectionTest] = useState<any>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [testLogs, setTestLogs] = useState<string[]>([]);

  const addLog = (message: string) => {
    setTestLogs((prev) => [
      ...prev,
      `${new Date().toLocaleTimeString()}: ${message}`,
    ]);
  };

  const testConnection = async () => {
    setRefreshing(true);
    setTestLogs([]);
    addLog("بدء اختبار الاتصال...");

    try {
      // Test basic connection
      addLog("اختبار جلسة المصادقة...");
      const { data: session, error: sessionError } =
        await supabase.auth.getSession();
      setSessionInfo({ session, error: sessionError });

      if (sessionError) {
        addLog(`خطأ في جلسة المصادقة: ${sessionError.message}`);
      } else {
        addLog("جلسة المصادقة تعمل بشكل صحيح");
      }

      // Test database connection
      addLog("اختبار اتصال قاعدة البيانات...");
      const { data: testData, error: dbError } = await supabase
        .from("users")
        .select("count")
        .limit(1);

      if (dbError) {
        addLog(`خطأ في قاعدة البيانات: ${dbError.message}`);
      } else {
        addLog("قاعدة البيانات متصلة بنجاح");
      }

      setConnectionTest({
        database: { success: !dbError, error: dbError?.message },
        auth: { success: !sessionError, error: sessionError?.message },
        timestamp: new Date().toISOString(),
      });

      addLog("انتهى اختبار الاتصال");
    } catch (err: any) {
      addLog(`خطأ غير متوقع: ${err.message}`);
      setConnectionTest({
        database: { success: false, error: err.message },
        auth: { success: false, error: err.message },
        timestamp: new Date().toISOString(),
      });
    } finally {
      setRefreshing(false);
    }
  };

  const testSignup = async () => {
    setRefreshing(true);
    addLog("اختبار تسجيل مستخدم تجريبي...");

    const testEmail = `test${Date.now()}@example.com`;
    const testPassword = "123456";

    try {
      const { data, error } = await supabase.auth.signUp({
        email: testEmail,
        password: testPassword,
      });

      if (error) {
        addLog(`خطأ في التسجيل: ${error.message}`);
        if (error.message.includes("Signup is disabled")) {
          addLog("⚠️ نظام التسجيل معطل في إعدادات Supabase");
        }
      } else {
        addLog("✅ تم إنشاء المستخدم التجريبي بنجاح");
        addLog(`البريد الإلكتروني: ${testEmail}`);
      }
    } catch (err: any) {
      addLog(`خطأ غير متوقع: ${err.message}`);
    }

    setRefreshing(false);
  };

  useEffect(() => {
    testConnection();
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 p-4">
      <div className="max-w-4xl mx-auto space-y-6">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">
            أداة تشخيص المصادقة
          </h1>
          <p className="text-gray-300">معلومات تفصيلية حول حالة النظام</p>
        </div>

        {/* Auth Status */}
        <Card className="bg-white/10 backdrop-blur-md border border-white/20">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <User className="w-5 h-5" />
              حالة المصادقة
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <p className="text-gray-300 text-sm">حالة التحميل</p>
                <Badge variant={loading ? "secondary" : "default"}>
                  {loading ? "جاري التحميل" : "مكتمل"}
                </Badge>
              </div>
              <div>
                <p className="text-gray-300 text-sm">حالة المستخدم</p>
                <Badge variant={user ? "default" : "secondary"}>
                  {user ? "مسجل الدخول" : "غير مسجل"}
                </Badge>
              </div>
              <div>
                <p className="text-gray-300 text-sm">الأخطاء</p>
                <Badge variant={error ? "destructive" : "default"}>
                  {error ? "يوجد خطأ" : "لا توجد أخطاء"}
                </Badge>
              </div>
            </div>

            {error && (
              <div className="bg-red-500/20 border border-red-500/50 rounded-lg p-4">
                <p className="text-red-200 text-sm font-medium">رسالة الخطأ:</p>
                <p className="text-red-100 text-sm mt-1">{error}</p>
              </div>
            )}

            {user && (
              <div className="bg-green-500/20 border border-green-500/50 rounded-lg p-4">
                <p className="text-green-200 text-sm font-medium">
                  معلومات المستخدم:
                </p>
                <div className="text-green-100 text-sm mt-2 space-y-1">
                  <p>المعرف: {user.id}</p>
                  <p>البريد الإلكتروني: {user.email}</p>
                  <p>
                    تأكيد البريد:{" "}
                    {user.email_confirmed_at ? "مؤكد" : "غير مؤكد"}
                  </p>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Connection Test */}
        <Card className="bg-white/10 backdrop-blur-md border border-white/20">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <Database className="w-5 h-5" />
              اختبار الاتصال
              <div className="ml-auto flex gap-2">
                <Button
                  onClick={testSignup}
                  disabled={refreshing}
                  size="sm"
                  variant="outline"
                  className="bg-green-600 hover:bg-green-700"
                >
                  اختبار التسجيل
                </Button>
                <Button
                  onClick={testConnection}
                  disabled={refreshing}
                  size="sm"
                  variant="outline"
                >
                  <RefreshCw
                    className={`w-4 h-4 ${refreshing ? "animate-spin" : ""}`}
                  />
                  تحديث
                </Button>
              </div>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {connectionTest && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <p className="text-gray-300 text-sm mb-2">
                    اتصال قاعدة البيانات
                  </p>
                  <Badge
                    variant={
                      connectionTest.database.success
                        ? "default"
                        : "destructive"
                    }
                  >
                    {connectionTest.database.success ? "متصل" : "فشل الاتصال"}
                  </Badge>
                  {connectionTest.database.error && (
                    <p className="text-red-300 text-xs mt-1">
                      {connectionTest.database.error}
                    </p>
                  )}
                </div>
                <div>
                  <p className="text-gray-300 text-sm mb-2">اتصال المصادقة</p>
                  <Badge
                    variant={
                      connectionTest.auth.success ? "default" : "destructive"
                    }
                  >
                    {connectionTest.auth.success ? "متصل" : "فشل الاتصال"}
                  </Badge>
                  {connectionTest.auth.error && (
                    <p className="text-red-300 text-xs mt-1">
                      {connectionTest.auth.error}
                    </p>
                  )}
                </div>
              </div>
            )}

            {testLogs.length > 0 && (
              <div className="mt-6">
                <h3 className="text-white font-medium mb-3">سجل الأحداث:</h3>
                <div className="bg-black/30 rounded-lg p-4 max-h-60 overflow-y-auto">
                  {testLogs.map((log, index) => (
                    <p
                      key={index}
                      className="text-gray-300 text-sm mb-1 font-mono"
                    >
                      {log}
                    </p>
                  ))}
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Session Info */}
        {sessionInfo && (
          <Card className="bg-white/10 backdrop-blur-md border border-white/20">
            <CardHeader>
              <CardTitle className="text-white flex items-center gap-2">
                <Settings className="w-5 h-5" />
                معلومات الجلسة
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="bg-gray-800/50 rounded-lg p-4 overflow-auto">
                <pre className="text-gray-300 text-xs">
                  {JSON.stringify(sessionInfo, null, 2)}
                </pre>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Environment Info */}
        <Card className="bg-white/10 backdrop-blur-md border border-white/20">
          <CardHeader>
            <CardTitle className="text-white">معلومات البيئة</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <p className="text-gray-300">رابط Supabase:</p>
                <p className="text-white font-mono text-xs break-all">
                  {import.meta.env.VITE_SUPABASE_URL || "غير محدد"}
                </p>
              </div>
              <div>
                <p className="text-gray-300">مفتاح Supabase:</p>
                <p className="text-white font-mono text-xs">
                  {import.meta.env.VITE_SUPABASE_ANON_KEY
                    ? `${import.meta.env.VITE_SUPABASE_ANON_KEY.substring(0, 20)}...`
                    : "غير محدد"}
                </p>
              </div>
              <div>
                <p className="text-gray-300">وضع التطوير:</p>
                <p className="text-white">{import.meta.env.MODE}</p>
              </div>
              <div>
                <p className="text-gray-300">Tempo:</p>
                <p className="text-white">
                  {import.meta.env.VITE_TEMPO || "غير مفعل"}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Alert className="bg-yellow-500/20 border-yellow-500/50">
          <AlertCircle className="h-4 w-4 text-yellow-400" />
          <AlertDescription className="text-yellow-200 text-right">
            <strong>ملاحظة:</strong> إذا كان التسجيل معطلاً، تحقق من إعدادات
            Supabase في لوحة التحكم:
            <br />• Authentication → Settings → Enable email confirmations
            <br />• Authentication → Settings → Disable email confirmations
            (للاختبار)
            <br />• Authentication → Settings → Enable manual email confirmation
          </AlertDescription>
        </Alert>

        <div className="text-center">
          <Button
            onClick={() => window.history.back()}
            variant="outline"
            className="bg-white/10 border-white/30 text-white hover:bg-white/20"
          >
            العودة
          </Button>
        </div>
      </div>
    </div>
  );
}
