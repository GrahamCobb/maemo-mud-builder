<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:transform version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:param name="sdk">chinook</xsl:param>

<!-- Handle SDK attribute, if present -->
<xsl:template match="*[@sdk]">
 <!-- Only copy the node if the sdk attribute matches -->
 <xsl:if test="@sdk=$sdk">
  <xsl:copy>
    <!-- Copy all the attributes except the sdk attribute -->
    <xsl:for-each select="@*">
       <xsl:if test="name()!='sdk'">
	<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
       </xsl:if>
    </xsl:for-each>
    <!-- And recurse -->
    <xsl:apply-templates/>
  </xsl:copy>
 </xsl:if>
</xsl:template>

<!-- If no SDK attribute, recurse to the next level -->
<xsl:template match="*[not(@sdk)]">
  <xsl:copy>
    <xsl:for-each select="@*">
	<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
    </xsl:for-each>
    <xsl:apply-templates/>
  </xsl:copy>
</xsl:template>

</xsl:transform>
