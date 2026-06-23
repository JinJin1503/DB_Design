-- ============================================================
-- Test 1: Kiểm thử bảo mật (Chống sửa điểm)
-- ============================================================
USE QuanLyDangKyHocPhan
GO

-- 1. Tạo một tài khoản Sinh viên giả lập và đưa vào Role_SinhVien
CREATE USER User_SV_Test WITHOUT LOGIN;
ALTER ROLE Role_SinhVien ADD MEMBER User_SV_Test;
GO

-- 2. Hệ thống đóng vai tài khoản Sinh viên này và cố tình sửa điểm
EXECUTE AS USER = 'User_SV_Test';
GO
-- Lệnh UPDATE này sẽ bị chặn lại!
UPDATE KetQuaHocTap SET TrangThaiQuaMon = N'Dat' WHERE MaSV = 'SV001';
GO
REVERT;
GO

-- 3. Xóa tài khoản giả lập sau khi test xong để dọn dẹp hệ thống
DROP USER User_SV_Test;
GO