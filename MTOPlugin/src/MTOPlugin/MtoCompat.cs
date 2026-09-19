using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;

namespace MTOPlugin
{
    /// <summary>
    /// Tien ich giao dien giua cac nhom AutoCAD.
    ///
    /// PHAT HIEN QUAN TRONG (da kiem chung bang reflection + build that):
    ///   AutoCAD 2023 (net48) dung API GIONG AutoCAD 2025 (net8):
    ///     - Extents3d nam o Autodesk.AutoCAD.DatabaseServices (khong phai Geometry)
    ///     - Extents3d KHONG co GetCenter()/IsValid() -> phai tu tinh
    ///     - BlockReference KHONG co EffectiveName -> dung Name
    ///     - ViewTableRecord nam o DatabaseServices (khong phai EditorInput)
    ///     - Handle nhan long (khong nhan ulong)
    ///     - BlockTableRecord KHONG co IsLoaded / IsOverlayReferenceOfExternalReference
    ///   => Ban cu cua file nay gia dinh NGUOC (net48 = API cu) nen build net48 that bai.
    ///
    /// Vi vay dung CHUNG mot implementation cho ca net48 (2023) va net8 (2025+).
    ///
    /// LIMITATION: AutoCAD 2018-2022 co the dung API cu hon; chua co may de
    /// kiem chung. Neu can ho tro nhom do, bo sung nhanh #if tai day.
    /// </summary>
    internal static class MtoCompat
    {
        public const string ModelSpaceName = "*Model_Space";

        /// <summary>Handle tu gia tri so (AutoCAD dung long).</summary>
        public static Handle NewHandle(ulong value) => new Handle(unchecked((long)value));

        /// <summary>BlockTableRecord co phai Xref khong.</summary>
        public static bool IsXrefReference(BlockTableRecord btr) => btr.IsFromExternalReference;

        /// <summary>Xref con nap khong.</summary>
        public static bool IsXrefLoaded(BlockTableRecord btr) => !btr.IsUnloaded;

        /// <summary>Ten block hieu dung (dynamic block tra ve ten dinh nghia).</summary>
        public static string EffectiveBlockName(BlockReference br) => br.Name;

        public static bool IsModelSpace(BlockTableRecord btr) => btr.Name == ModelSpaceName;

        /// <summary>Tam cua extents (2023 khong co GetCenter).</summary>
        public static Point3d ExtentsCenter(Extents3d e) => new Point3d(
            (e.MinPoint.X + e.MaxPoint.X) / 2.0,
            (e.MinPoint.Y + e.MaxPoint.Y) / 2.0,
            (e.MinPoint.Z + e.MaxPoint.Z) / 2.0);

        /// <summary>Extents co hop le khong (2023 khong co IsValid).</summary>
        public static bool ExtentsValid(Extents3d e)
        {
            double w = e.MaxPoint.X - e.MinPoint.X;
            double h = e.MaxPoint.Y - e.MinPoint.Y;
            double d = e.MaxPoint.Z - e.MinPoint.Z;
            return w > 1e-12 || h > 1e-12 || d > 1e-12;
        }

        /// <summary>Dat khung nhin hien tai (ViewTableRecord o DatabaseServices).</summary>
        public static void SetView(Editor editor, double centerX, double centerY, double height, double width)
        {
            var v = new Autodesk.AutoCAD.DatabaseServices.ViewTableRecord
            {
                CenterPoint = new Point2d(centerX, centerY),
                Height = height,
                Width = width
            };
            editor.SetCurrentView(v);
        }
    }
}
