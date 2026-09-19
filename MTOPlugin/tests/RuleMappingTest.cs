using System;
using System.Collections.Generic;
using System.Linq;
using MTOPlugin.Core.Classification;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Rules;

/// <summary>
/// TEST: Chung minh rang BO QUY TAC (Rule Editor) dung de MAP ten cua ky su
/// sang danh muc vat tu chuan cua cong ty.
///
/// Kich ban: block trong ban ve ten "SE.DOME CAMERA" (cach dat ten cua ky su),
///           KHONG giong bo quy tac mau (dung "ELV-CAM-DOME-*").
///
/// 1) Chay voi bo quy tac MAU  -> mong doi: CHUA PHAN LOAI
/// 2) Them 1 rule map ten do  -> mong doi: PHAN LOAI DUNG (he ELV, ma vat tu, don vi)
/// </summary>
internal static class RuleMappingTest
{
    private static int _pass;
    private static int _fail;

    private static void Check(string name, bool ok, string detail)
    {
        if (ok) { _pass++; Console.WriteLine("  PASS | " + name); }
        else { _fail++; Console.WriteLine("  FAIL | " + name + "  -> " + detail); }
    }

    private static ScanResult MakeScan(params string[] blockNames)
    {
        var scan = new ScanResult
        {
            DrawingFile = "MB Camera khu Restaurant,Recepption.dwg",
            Unit = new UnitInfo { SourceUnitText = "mm", OutputUnit = "mm" }
        };
        foreach (var bn in blockNames)
        {
            scan.Blocks.Add(new BlockReferenceInfo
            {
                BlockName = bn,
                Layer = "CCTV",
                PositionX = 1.0,
                PositionY = 2.0
            });
        }
        return scan;
    }

    private static int Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        Console.WriteLine("=== TEST MAP TEN KY SU -> DANH MUC VAT TU CHUAN ===");
        Console.WriteLine();

        // ---------- 1. Bo quy tac MAU (khong co ten that cua ban ve) ----------
        string samplePath = args.Length > 0 ? args[0] : "rules.sample.json";
        RuleSet sample = null;
        try
        {
            sample = RuleSetLoader.Load(samplePath);
            Console.WriteLine("Bo quy tac mau: " + sample.Rules.Count + " rule, "
                              + sample.ActiveRules.Count() + " active");
        }
        catch (Exception ex)
        {
            Console.WriteLine("KHONG LOAD duoc rules.sample.json: " + ex.Message);
            return 2;
        }

        var engine1 = new ClassificationEngine(sample, new UnitInfo());
        var r1 = engine1.Classify(MakeScan("SE.DOME CAMERA"));

        Console.WriteLine();
        Console.WriteLine("--- 1) BLOCK 'SE.DOME CAMERA' voi BO QUY TAC MAU ---");
        Console.WriteLine("  Phan loai duoc : " + r1.Details.Count);
        Console.WriteLine("  Chua phan loai : " + r1.Unclassified.Count);
        if (r1.Unclassified.Count > 0)
            Console.WriteLine("  Ly do          : " + r1.Unclassified[0].Reason);

        // Kiem tra bo quy tac co chua rule nhan dang "SE.DOME" khong:
        //  - Bo quy tac MAU (110 rule, dung ELV-CAM-DOME-*) -> KHONG co
        //  - Bo quy tac sinh tu Excel danh muc cong ty       -> CO
        bool hasDomeRule = false;
        foreach (var r in sample.ActiveRules)
            foreach (var c in r.Conditions)
                if (c.BlockNames != null &&
                    c.BlockNames.IndexOf("SE.DOME", StringComparison.OrdinalIgnoreCase) >= 0)
                    hasDomeRule = true;

        Console.WriteLine("  Co rule nhan 'SE.DOME'? " + (hasDomeRule ? "CO" : "KHONG"));
        if (r1.Details.Count > 0)
            Console.WriteLine("  => Ma vat tu   : " + r1.Details[0].MaterialCode);

        if (hasDomeRule)
            Check("co rule SE.DOME -> 'SE.DOME CAMERA' PHAN LOAI duoc",
                  r1.Details.Count == 1 && r1.Unclassified.Count == 0,
                  "Details=" + r1.Details.Count + " Unclassified=" + r1.Unclassified.Count);
        else
            Check("khong co rule SE.DOME -> 'SE.DOME CAMERA' CHUA phan loai",
                  r1.Details.Count == 0 && r1.Unclassified.Count == 1,
                  "Details=" + r1.Details.Count + " Unclassified=" + r1.Unclassified.Count);

        // ---------- 2. THEM 1 RULE map ten do ----------
        var custom = new RuleSet { Name = "Bo quy tac du an Camera", Version = "1.0" };
        custom.Systems.Add(new SystemDefinition { Code = "HE-ELV", Name = "Dien nhe / ELV" });
        custom.Rules.Add(new RuleDefinition
        {
            Code = "R-ELV-CAM-001",
            Description = "Camera dome - nhan dang theo ten block cua ky su",
            SystemCode = "HE-ELV",
            MaterialCode = "VL-CCTV-001",
            MaterialName = "Camera Dome IP",
            Specification = "2MP, PoE",
            Unit = "cai",
            Calculation = CalculationKind.Count,
            Factor = 1.0,
            Priority = 100,
            Status = RuleStatus.Active,
            Conditions = new List<RuleCondition>
            {
                new RuleCondition
                {
                    EntityKind = "block",
                    BlockNames = "SE.DOME*;*DOME CAMERA*",   // <-- MAP ten that
                    Layers = "*"
                }
            }
        });

        Console.WriteLine();
        Console.WriteLine("--- 2) THEM RULE map 'SE.DOME*' -> VL-CCTV-001 ---");
        Console.WriteLine("  Rule: " + custom.Rules[0].Code + " | "
                          + custom.Rules[0].MaterialCode + " | "
                          + custom.Rules[0].MaterialName + " | "
                          + custom.Rules[0].Unit);

        var engine2 = new ClassificationEngine(custom, new UnitInfo());
        var r2 = engine2.Classify(MakeScan("SE.DOME CAMERA"));

        Console.WriteLine();
        Console.WriteLine("  Phan loai duoc : " + r2.Details.Count);
        Console.WriteLine("  Chua phan loai : " + r2.Unclassified.Count);
        if (r2.Details.Count > 0)
        {
            var d = r2.Details[0];
            Console.WriteLine("  => He          : " + d.SystemCode);
            Console.WriteLine("  => Ma vat tu   : " + d.MaterialCode);
            Console.WriteLine("  => Ten vat tu  : " + d.MaterialName);
            Console.WriteLine("  => Quy cach    : " + d.Specification);
            Console.WriteLine("  => Don vi      : " + d.Unit);
            Console.WriteLine("  => Khoi luong  : " + d.Quantity);
        }

        Check("co rule: 'SE.DOME CAMERA' PHAN LOAI duoc",
              r2.Details.Count == 1 && r2.Unclassified.Count == 0,
              "Details=" + r2.Details.Count);
        Check("gan dung ma vat tu VL-CCTV-001",
              r2.Details.Count > 0 && r2.Details[0].MaterialCode == "VL-CCTV-001",
              r2.Details.Count > 0 ? r2.Details[0].MaterialCode : "(khong co)");
        Check("gan dung he HE-ELV",
              r2.Details.Count > 0 && r2.Details[0].SystemCode == "HE-ELV",
              r2.Details.Count > 0 ? r2.Details[0].SystemCode : "(khong co)");
        Check("gan dung don vi 'cai'",
              r2.Details.Count > 0 && r2.Details[0].Unit == "cai",
              r2.Details.Count > 0 ? r2.Details[0].Unit : "(khong co)");

        // ---------- 3. Nhieu lan chen: moi doi tuong 1 dong CHI TIET ----------
        // (Details = chi tiet tung doi tuong; tong khoi luong cong don dung)
        var r3 = engine2.Classify(MakeScan("SE.DOME CAMERA", "SE.DOME CAMERA", "SE.DOME CAMERA"));
        double totalQty = 0;
        foreach (var d in r3.Details) totalQty += d.Quantity;
        Console.WriteLine();
        Console.WriteLine("--- 3) 3 lan chen 'SE.DOME CAMERA' ---");
        Console.WriteLine("  So dong chi tiet : " + r3.Details.Count);
        Console.WriteLine("  Tong khoi luong  : " + totalQty);
        Check("3 lan chen -> TONG khoi luong = 3",
              Math.Abs(totalQty - 3.0) < 0.001,
              "total=" + totalQty);

        Console.WriteLine();
        Console.WriteLine("======================================================");
        Console.WriteLine("KET QUA: " + _pass + " PASS / " + _fail + " FAIL");
        Console.WriteLine(_fail == 0
            ? "=> BO QUY TAC MAP DUOC ten ky su sang danh muc vat tu chuan"
            : "=> CO VAN DE - xem chi tiet ben tren");
        Console.WriteLine("======================================================");
        return _fail == 0 ? 0 : 1;
    }
}
