using System.Web.Mvc;
using NUnit.Framework;
using WebApplication.Controllers;

namespace WebApplication.NUnitTests.Controllers
{
    [TestFixture]
    public class HomeControllerTest
    {
        [Test]
        public void Index()
        {
            // Arrange
            HomeController controller = new HomeController();

            // Act
            ViewResult result = controller.Index() as ViewResult;

            // Assert
            Assert.IsNotNull(result);
        }

        //[Test]
        //public void test_foo()
        //{
        //    Assert.Fail("this test fails on purpose to see how build reports this");
        //}
    }
}
