using System;
using System.IO;
using System.Reflection;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Windows.Forms;
using System.Threading;

[assembly: AssemblyTitle("Hora de Estudar")]
[assembly: AssemblyProduct("Hora de Estudar")]
[assembly: AssemblyVersion("1.0.0.0")]
internal static class Program {
    [STAThread]
    private static int Main() {
        try {
            using (var source = new StreamReader(Assembly.GetExecutingAssembly().GetManifestResourceStream("Estudo.ps1")))
            using (var session = RunspaceFactory.CreateRunspace())
            using (var shell = PowerShell.Create()) {
                session.ApartmentState = ApartmentState.STA;
                session.ThreadOptions = PSThreadOptions.UseCurrentThread;
                session.Open();
                shell.Runspace = session;
                shell.AddScript(source.ReadToEnd()).Invoke();
                if (shell.HadErrors) throw new InvalidOperationException(shell.Streams.Error[0].ToString());
            }
            return 0;
        } catch (Exception failure) {
            MessageBox.Show(failure.Message, "Hora de Estudar", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
