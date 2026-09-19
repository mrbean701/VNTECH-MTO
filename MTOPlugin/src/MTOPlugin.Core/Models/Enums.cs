namespace MTOPlugin.Core.Models
{
    /// <summary>
    /// Pham vi quet b�n ve. Ung voi yeu cau FR01.
    /// </summary>
    public enum ScanScope
    {
        /// <summary>Chi quet cac doi tuong duoc chon bang vung chon.</summary>
        Selection = 0,

        /// <summary>Toan bo Model space cua file dang mo.</summary>
        ModelSpace = 1,

        /// <summary>Toan bo Model space + layout dang hien tai.</summary>
        CurrentLayout = 2,

        /// <summary>Toan bo cac Layout (paper space).</summary>
        AllLayouts = 3,

        /// <summary>Model space + toan bo Layout.</summary>
        ModelAndAllLayouts = 4
    }

    /// <summary>
    /// Che do tinh Xref. Ung voi yeu cau FR05.
    /// </summary>
    public enum XrefMode
    {
        /// <summary>Khong tinh doi tuong nam trong Xref.</summary>
        Ignore = 0,

        /// <summary>Tinh mot lan theo file nguon (khong trung lap khi chen nhieu lan).</summary>
        UniqueBySource = 1,

        /// <summary>Tinh theo tung lan chen (moi reference block dem rieng).</summary>
        PerInsertion = 2
    }

    /// <summary>
    /// Khong gian chua doi tuong: Model space hay Paper space (Layout).
    /// </summary>
    public enum SpaceKind
    {
        Model = 0,
        Paper = 1
    }

    /// <summary>
    /// Loai doi tuong hinh hoc duoc ho tro do chieu dai.
    /// </summary>
    public enum GeometryKind
    {
        Line = 0,
        Polyline2D = 1,
        Polyline3D = 2,
        Arc = 3,
        Circle = 4,
        Polyline = 5,
        Unsupported = 99
    }

    /// <summary>
    /// Loai doi tuong tong quat khi duyet trong ban ve.
    /// </summary>
    public enum EntityKind
    {
        BlockReference = 0,
        Geometry = 1,
        Other = 2
    }
}