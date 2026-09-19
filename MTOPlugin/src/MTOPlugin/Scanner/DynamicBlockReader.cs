using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.DatabaseServices;
using MTOPlugin.Core;
using MTOPlugin.Core.Models;

namespace MTOPlugin.Scanner
{
    /// <summary>
    /// AutoCAD implementation of IDynamicBlockReader.
    /// Su dung AutoCAD .NET API de doc dynamic block properties.
    /// </summary>
    public sealed class DynamicBlockReader : IDynamicBlockReader
    {
        /// <summary>
        /// Kiem tra mot block reference co phai dynamic block khong.
        /// </summary>
        public bool IsDynamicBlock(BlockReferenceInfo block)
        {
            return block?.IsDynamic == true;
        }

        /// <summary>
        /// Doc tat ca dynamic properties cua mot dynamic block.
        /// Tra ve dictionary: ten property -> gia tri (object).
        /// </summary>
        public Dictionary<string, object> ReadDynamicProperties(BlockReferenceInfo block)
        {
            var result = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);

            if (block == null || !block.IsDynamic || string.IsNullOrEmpty(block.DynamicBlockName))
                return result;

            return result;
        }

        /// <summary>
        /// Doc tat ca dynamic properties tu mot BlockReference that su.
        /// Day la phuong thuc chinh duoc goi tu AutoCadScanner.
        /// </summary>
        public Dictionary<string, object> ReadDynamicPropertiesFromBlock(BlockReference br, Transaction tr)
        {
            var result = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);

            if (br == null || !br.IsDynamicBlock)
                return result;

            try
            {
                // Dung chung cho ca net48 (AutoCAD 2023) va net8 (2025+):
                // KHONG co extension GetDynamicBlockProperties(), dung thuoc tinh
                // DynamicBlockReferencePropertyCollection.
                using (var props = br.DynamicBlockReferencePropertyCollection)
                {
                    if (props != null)
                    {
                        foreach (DynamicBlockReferenceProperty prop in props)
                        {
                            try
                            {
                                string name = prop.PropertyName;
                                object value = GetPropertyValue(prop);
                                if (!string.IsNullOrEmpty(name))
                                {
                                    result[name] = value;
                                }
                            }
                            catch (Exception)
                            {
                            }
                        }
                    }
                }
            }
            catch (Exception)
            {
            }

            return result;
        }

        /// <summary>
        /// Doc gia tri cua mot dynamic property cu the.
        /// Tra ve null neu property khong ton tai hoac block khong phai dynamic.
        /// </summary>
        public object GetPropertyValue(BlockReferenceInfo block, string propertyName)
        {
            if (block == null || string.IsNullOrEmpty(propertyName))
                return null;

            if (block.DynamicProperties == null)
                return null;

            return block.DynamicProperties.TryGetValue(propertyName, out var value) ? value : null;
        }

        /// <summary>
        /// Lay ten hien thi (effective name) cua dynamic block.
        /// Neu khong phai dynamic block, tra ve BlockName goc.
        /// </summary>
        public string GetEffectiveName(BlockReferenceInfo block)
        {
            if (block == null)
                return null;

            if (block.IsDynamic && !string.IsNullOrEmpty(block.EffectiveName))
                return block.EffectiveName;

            return block.BlockName;
        }

        /// <summary>
        /// Lay gia tri tu DynamicBlockReferenceProperty.
        /// Chuyen doi thanh type phu hop.
        /// </summary>
        private static object GetPropertyValue(DynamicBlockReferenceProperty prop)
        {
            if (prop == null)
                return null;

            try
            {
#if NET8_0_OR_GREATER
                switch (prop.PropertyType)
                {
                    case DynamicBlockReferencePropertyType.Distance:
                    case DynamicBlockReferencePropertyType.DistanceX:
                    case DynamicBlockReferencePropertyType.DistanceY:
                    case DynamicBlockReferencePropertyType.DistanceZ:
                        return prop.Value;

                    case DynamicBlockReferencePropertyType.Integer:
                        if (prop.Value is int intVal)
                            return intVal;
                        if (int.TryParse(prop.Value?.ToString(), out int parsedInt))
                            return parsedInt;
                        return prop.Value;

                    case DynamicBlockReferencePropertyType.Boolean:
                        if (prop.Value is bool boolVal)
                            return boolVal;
                        if (bool.TryParse(prop.Value?.ToString(), out bool parsedBool))
                            return parsedBool;
                        return prop.Value;

                    case DynamicBlockReferencePropertyType.String:
                        return prop.Value?.ToString();

                    case DynamicBlockReferencePropertyType.Enumerated:
                        return prop.Value;

                    case DynamicBlockReferencePropertyType.Point:
                        return prop.Value;

                    default:
                        return prop.Value;
                }
#else
                // AutoCAD 2023 (net48): DynamicBlockReferenceProperty KHONG co
                // 'PropertyType' ma chi co 'PropertyTypeCode' (int). Gia tri 'Value'
                // da duoc AutoCAD chuan hoa san theo dung kieu => tra truc tiep.
                return prop.Value;
#endif
            }
            catch
            {
                return prop.Value;
            }
        }

        /// <summary>
        /// Lay ten visibility state hien tai cua dynamic block.
        /// </summary>
        public string GetVisibilityStateName(BlockReference br, Transaction tr)
        {
            if (br == null || !br.IsDynamicBlock)
                return null;

            try
            {
#if NET8_0_OR_GREATER
                using (var props = br.GetDynamicBlockProperties())
                {
                    if (props != null)
                    {
                        foreach (DynamicBlockReferenceProperty prop in props)
                        {
                            if (prop.PropertyType == DynamicBlockReferencePropertyType.Enumerated &&
                                prop.PropertyName != null &&
                                prop.PropertyName.IndexOf("Visibility", StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                return prop.Value?.ToString();
                            }
                        }
                    }
                }
#else
                // AutoCAD 2023: truy cap qua thuoc tinh collection (khong co extension
                // GetDynamicBlockProperties()). Nhan dien Visibility theo PropertyName.
                using (var props = br.DynamicBlockReferencePropertyCollection)
                {
                    if (props != null)
                    {
                        foreach (DynamicBlockReferenceProperty prop in props)
                        {
                            if (prop.PropertyName != null &&
                                prop.PropertyName.IndexOf("Visibility", StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                return prop.Value?.ToString();
                            }
                        }
                    }
                }
#endif
            }
            catch
            {
            }

            return null;
        }

        /// <summary>
        /// Doc property theo ten (hien thi, kich thuoc, etc).
        /// </summary>
        public object GetPropertyByName(BlockReference br, string propertyName, Transaction tr)
        {
            if (br == null || string.IsNullOrEmpty(propertyName))
                return null;

            try
            {
#if NET8_0_OR_GREATER
                using (var props = br.GetDynamicBlockProperties())
                {
                    if (props != null)
                    {
                        foreach (DynamicBlockReferenceProperty prop in props)
                        {
                            if (string.Equals(prop.PropertyName, propertyName, StringComparison.OrdinalIgnoreCase))
                            {
                                return GetPropertyValue(prop);
                            }
                        }
                    }
                }
#else
                using (var props = br.DynamicBlockReferencePropertyCollection)
                {
                    if (props != null)
                    {
                        foreach (DynamicBlockReferenceProperty prop in props)
                        {
                            if (string.Equals(prop.PropertyName, propertyName, StringComparison.OrdinalIgnoreCase))
                            {
                                return GetPropertyValue(prop);
                            }
                        }
                    }
                }
#endif
            }
            catch
            {
            }

            return null;
        }
    }
}
